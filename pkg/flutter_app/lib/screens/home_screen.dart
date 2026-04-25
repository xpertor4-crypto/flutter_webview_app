import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<HtmlFile> _files = [];
  bool _loading = true;
  bool _uploading = false;
  String? _username;
  String? _role;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _username = await ApiService.getUsername();
    _role = await ApiService.getRole();
    _serverUrl = await ApiService.getServerUrl();
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final files = await ApiService.listFiles();
      setState(() => _files = files);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to load files. Check server connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await ApiService.uploadFile(File(path));
      setState(() => _files.insert(0, uploaded));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${uploaded.originalName}" uploaded'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteFile(HtmlFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.originalName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteFile(file.filename);
      setState(() => _files.removeWhere((f) => f.filename == file.filename));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted'), backgroundColor: AppTheme.error),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  void _openWebView(HtmlFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: file.fullUrl,
          title: file.originalName,
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('WebView Manager'),
        backgroundColor: AppTheme.primary,
        actions: [
          // Upload button (admin only)
          if (_role == 'admin')
            _uploading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    onPressed: _uploadFile,
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Upload HTML file',
                  ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'server') _showServerDialog();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'info',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _username ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      _role?.toUpperCase() ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'server',
                  child: Row(children: [
                    Icon(Icons.dns_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Server Settings'),
                  ])),
              const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Stats bar ──────────────────────────────────────────────────
          Container(
            color: AppTheme.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _statChip(
                    Icons.html, '${_files.length}', 'HTML files'),
                const SizedBox(width: 16),
                _statChip(Icons.storage_outlined, _serverUrl ?? '—',
                    'Server', small: true),
              ],
            ),
          ),

          // ── File list ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : _files.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        color: AppTheme.accent,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _fileCard(_files[i]),
                        ),
                      ),
          ),
        ],
      ),

      // FAB for upload
      floatingActionButton: _role == 'admin'
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _uploadFile,
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Upload HTML',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _statChip(IconData icon, String value, String label,
      {bool small = false}) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 14),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 11 : 14,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _fileCard(HtmlFile file) {
    return Card(
      child: InkWell(
        onTap: () => _openWebView(file),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.html,
                    color: AppTheme.accent, size: 24),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.originalName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${file.formattedSize} · ${_formatDate(file.uploadedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _openWebView(file),
                    icon: const Icon(Icons.open_in_browser,
                        color: AppTheme.accent, size: 20),
                    tooltip: 'Open in WebView',
                  ),
                  if (_role == 'admin')
                    IconButton(
                      onPressed: () => _deleteFile(file),
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.error, size: 20),
                      tooltip: 'Delete',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.html,
                color: AppTheme.accent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'No HTML files yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _role == 'admin'
                ? 'Tap the + button to upload your first HTML file'
                : 'No files have been uploaded yet',
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showServerDialog() async {
    final ctrl =
        TextEditingController(text: await ApiService.getServerUrl());
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:3000',
              labelText: 'Backend URL'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.setServerUrl(ctrl.text.trim());
              if (mounted) {
                setState(() => _serverUrl = ctrl.text.trim());
                Navigator.pop(context);
                _loadFiles();
              }
            },
            child: const Text('Save & Reload'),
          ),
        ],
      ),
    );
  }
}
