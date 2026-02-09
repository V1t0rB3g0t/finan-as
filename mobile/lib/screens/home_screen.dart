import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audio_job.dart';
import '../services/api_client.dart';
import 'auth_screen.dart';
import 'import_screen.dart';
import 'processing_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<AudioJob> _jobs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.fetchJobs();
      final jobs = (response['jobs'] as List<dynamic>)
          .map((job) => AudioJob.fromJson(job as Map<String, dynamic>))
          .toList();
      setState(() => _jobs = jobs);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await widget.apiClient.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthScreen(apiClient: widget.apiClient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Base44 - Áudio IA'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordScreen(apiClient: widget.apiClient),
                        ),
                      );
                      if (result == true) {
                        _loadJobs();
                      }
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('Gravar áudio'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImportScreen(apiClient: widget.apiClient),
                        ),
                      );
                      if (result == true) {
                        _loadJobs();
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar áudio'),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            const Text('Jobs recentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_loading && _jobs.isEmpty)
              const Text('Nenhum job ainda. Grave ou importe um áudio.'),
            ..._jobs.map((job) {
              final formatter = DateFormat('dd/MM/yyyy HH:mm');
              return Card(
                child: ListTile(
                  title: Text(job.originalFilename),
                  subtitle: Text('Criado em ${formatter.format(job.createdAt)}'),
                  trailing: _StatusBadge(status: job.status),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProcessingScreen(
                          apiClient: widget.apiClient,
                          jobId: job.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'UPLOADING':
        color = Colors.orange;
        label = 'Enviando';
        break;
      case 'TRANSCRIBING':
        color = Colors.blue;
        label = 'Transcrevendo';
        break;
      case 'ANALYZING':
        color = Colors.purple;
        label = 'Analisando';
        break;
      case 'DONE':
        color = Colors.green;
        label = 'Concluído';
        break;
      default:
        color = Colors.red;
        label = 'Erro';
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }
}
