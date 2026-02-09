import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'processing_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  File? _file;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
      });
    }
  }

  Future<void> _upload() async {
    if (_file == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.uploadFile(_file!);
      final jobId = response['job_id'] as String;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(apiClient: widget.apiClient, jobId: jobId),
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar áudio')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Selecionar arquivo'),
            ),
            const SizedBox(height: 12),
            if (_file != null) Text('Arquivo: ${_file!.path.split('/').last}'),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _upload,
              child: Text(_loading ? 'Enviando...' : 'Enviar'),
            )
          ],
        ),
      ),
    );
  }
}
