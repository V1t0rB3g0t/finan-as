import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_client.dart';
import 'processing_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _elapsed = Duration.zero;
  String? _filePath;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording && !_isPaused) {
        setState(() => _elapsed = _elapsed + const Duration(seconds: 1));
      }
    });
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _elapsed = Duration.zero;
      _filePath = filePath;
    });
  }

  Future<void> _pause() async {
    await _recorder.pause();
    setState(() => _isPaused = true);
  }

  Future<void> _resume() async {
    await _recorder.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _stop() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _finishAndUpload() async {
    if (_filePath == null) return;
    final file = File(_filePath!);
    final response = await widget.apiClient.uploadFile(file);
    final jobId = response['job_id'] as String;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(apiClient: widget.apiClient, jobId: jobId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Gravar áudio')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text('$minutes:$seconds', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(_isRecording ? (_isPaused ? 'Pausado' : 'Gravando...') : 'Pronto para gravar'),
            const Spacer(),
            if (!_isRecording)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic),
                label: const Text('Iniciar gravação'),
              ),
            if (_isRecording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _isPaused ? _resume : _pause,
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                  IconButton(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                  )
                ],
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: !_isRecording && _filePath != null ? _finishAndUpload : null,
              child: const Text('Finalizar e enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
