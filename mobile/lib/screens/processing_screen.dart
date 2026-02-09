import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_job.dart';
import '../services/api_client.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.apiClient, required this.jobId});

  final ApiClient apiClient;
  final String jobId;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  Timer? _timer;
  AudioJob? _job;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final response = await widget.apiClient.fetchJob(widget.jobId);
      final job = AudioJob.fromJson(response['job'] as Map<String, dynamic>);
      setState(() => _job = job);
      if (job.status == 'DONE') {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(apiClient: widget.apiClient, jobId: job.id),
          ),
        );
      }
      if (job.status == 'ERROR') {
        _timer?.cancel();
      }
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _stepIndex(String status) {
    switch (status) {
      case 'UPLOADING':
        return 0;
      case 'TRANSCRIBING':
        return 1;
      case 'ANALYZING':
        return 2;
      case 'DONE':
        return 3;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _job?.status ?? 'UPLOADING';
    final current = _stepIndex(status);

    return Scaffold(
      appBar: AppBar(title: const Text('Processando áudio')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stepper(
              currentStep: current,
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: const [
                Step(title: Text('Enviando'), content: SizedBox.shrink(), isActive: true),
                Step(title: Text('Transcrevendo'), content: SizedBox.shrink(), isActive: true),
                Step(title: Text('Analisando'), content: SizedBox.shrink(), isActive: true),
                Step(title: Text('Concluído'), content: SizedBox.shrink(), isActive: true),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status atual: $status'),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (status == 'ERROR')
              const Text('Ocorreu um erro. Tente novamente ou reanalise.'),
          ],
        ),
      ),
    );
  }
}
