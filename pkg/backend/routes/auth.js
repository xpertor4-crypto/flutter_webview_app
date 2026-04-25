const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-change-in-production';

// In-memory user store (replace with a real DB in production)
const USERS = [
  {
    id: '1',
    username: 'admin',
    // Default password: admin123
    passwordHash: '$2a$10$eVSkjxCJQ.ydnaLFiNos3uM63/X7ow0mVbm7flCnNiZkJfaxrAJp2',
    role: 'admin',
  },
  {
    id: '2',
    username: 'viewer',
    // Default password: viewer123
    passwordHash: '$2a$10$2GooIiHlz10C98lup9.8ve5pHdDher7M7688WyvHEgc1fom5jpdt6',
    role: 'viewer',
  },
];

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required.' });
    }

    const user = USERS.find((u) => u.username === username.trim().toLowerCase());
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: { id: user.id, username: user.username, role: user.role },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error.' });
  }
});

// POST /api/auth/verify  — verify a JWT
router.post('/verify', (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'Token required.' });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    res.json({ valid: true, user: decoded });
  } catch {
    res.status(401).json({ valid: false, error: 'Invalid or expired token.' });
  }
});

module.exports = router;
module.exports.JWT_SECRET = JWT_SECRET;
