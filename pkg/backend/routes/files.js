const express = require('express');
const multer = require('multer');
const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();
const { JWT_SECRET } = require('./auth');

const uploadsDir = path.join(__dirname, '..', 'uploads');

// ── Multer config ──────────────────────────────────────────────────────────────
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    // Sanitise: keep original name but prefix with timestamp + uuid slug
    const ext = path.extname(file.originalname).toLowerCase();
    const base = path
      .basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .slice(0, 60);
    const unique = `${Date.now()}_${uuidv4().split('-')[0]}_${base}${ext}`;
    cb(null, unique);
  },
});

const fileFilter = (_req, file, cb) => {
  if (file.mimetype === 'text/html' || path.extname(file.originalname).toLowerCase() === '.html') {
    cb(null, true);
  } else {
    cb(new Error('Only .html files are allowed.'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

// ── JWT Auth middleware ────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) return res.status(401).json({ error: 'Authentication required.' });

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
}

function requireAdmin(req, res, next) {
  requireAuth(req, res, () => {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required.' });
    }
    next();
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────────
function getFileList() {
  if (!fs.existsSync(uploadsDir)) return [];
  return fs
    .readdirSync(uploadsDir)
    .filter((f) => f.endsWith('.html'))
    .map((filename) => {
      const stat = fs.statSync(path.join(uploadsDir, filename));
      return {
        filename,
        originalName: filename.replace(/^\d+_[a-f0-9]+_/, ''), // strip prefix
        size: stat.size,
        uploadedAt: stat.birthtime.toISOString(),
        url: `/html/${filename}`,
      };
    })
    .sort((a, b) => new Date(b.uploadedAt) - new Date(a.uploadedAt));
}

// ── Routes ─────────────────────────────────────────────────────────────────────

// GET /api/files  — list all uploaded HTML files (auth required)
router.get('/', requireAuth, (req, res) => {
  const files = getFileList();
  res.json({ files, total: files.length });
});

// POST /api/files/upload  — upload a new HTML file (admin only)
router.post('/upload', requireAdmin, upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  const file = {
    filename: req.file.filename,
    originalName: req.file.originalname,
    size: req.file.size,
    uploadedAt: new Date().toISOString(),
    url: `/html/${req.file.filename}`,
  };

  res.status(201).json({ message: 'File uploaded successfully.', file });
});

// DELETE /api/files/:filename  — delete a file (admin only)
router.delete('/:filename', requireAdmin, (req, res) => {
  const { filename } = req.params;

  // Safety: no path traversal
  if (filename.includes('..') || filename.includes('/')) {
    return res.status(400).json({ error: 'Invalid filename.' });
  }

  const filePath = path.join(uploadsDir, filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found.' });
  }

  fs.unlinkSync(filePath);
  res.json({ message: 'File deleted successfully.' });
});

// GET /api/files/:filename/content  — get raw HTML content (auth required)
router.get('/:filename/content', requireAuth, (req, res) => {
  const { filename } = req.params;

  if (filename.includes('..') || filename.includes('/')) {
    return res.status(400).json({ error: 'Invalid filename.' });
  }

  const filePath = path.join(uploadsDir, filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found.' });
  }

  const content = fs.readFileSync(filePath, 'utf-8');
  res.json({ filename, content });
});

module.exports = router;
