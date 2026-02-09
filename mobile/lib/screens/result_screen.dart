import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_job.dart';
import '../services/api_client.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.apiClient, required this.jobId});

  final ApiClient apiClient;
  final String jobId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  AudioJob? _job;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.fetchJob(widget.jobId);
      setState(() => _job = AudioJob.fromJson(response['job'] as Map<String, dynamic>));
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(\n      const SnackBar(content: Text('Texto copiado para a área de transferência')),\n    );
  }

  Future<void> _shareText(String text) async {
    await Share.share(text);
  }

  Future<void> _exportPdf() async {
    if (_job == null) return;
    final pdf = pw.Document();
    final analysis = _job?.analysis ?? {};

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Relatório de Transcrição', style: pw.TextStyle(fontSize: 20)),
          pw.SizedBox(height: 8),
          pw.Text('Data: ${DateTime.now()}'),
          pw.SizedBox(height: 16),
          pw.Text('Transcrição limpa', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 6),
          pw.Text(_job?.transcriptClean ?? ''),
          pw.SizedBox(height: 12),
          pw.Text('Resumo executivo', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 6),
          pw.Text(analysis['executive_summary']?.toString() ?? ''),
          pw.SizedBox(height: 12),
          pw.Text('Tópicos-chave', style: pw.TextStyle(fontSize: 16)),
          pw.Bullet(text: (analysis['key_topics'] as List<dynamic>? ?? []).join(', ')),
          pw.SizedBox(height: 12),
          pw.Text('Ações', style: pw.TextStyle(fontSize: 16)),
          ...((analysis['action_items'] as List<dynamic>? ?? []).map((item) {
            final data = item as Map<String, dynamic>;
            return pw.Bullet(
              text: '${data['task']} (Dono: ${data['owner']}, Prioridade: ${data['priority']})',
            );
          })),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/relatorio_${_job!.id}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    await Printing.sharePdf(bytes: bytes, filename: file.path.split('/').last);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    final job = _job;
    if (job == null) {
      return const Scaffold(body: Center(child: Text('Job não encontrado')));
    }

    final analysis = job.analysis ?? {};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resultado'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Transcrição limpa'),
              Tab(text: 'Transcrição bruta'),
              Tab(text: 'Análise'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ResultTab(
              text: job.transcriptClean ?? 'Sem transcrição limpa.',
              onCopy: () => _copyText(job.transcriptClean ?? ''),
              onShare: () => _shareText(job.transcriptClean ?? ''),
              onExport: _exportPdf,
            ),
            _ResultTab(
              text: job.transcriptRaw ?? 'Sem transcrição bruta.',
              onCopy: () => _copyText(job.transcriptRaw ?? ''),
              onShare: () => _shareText(job.transcriptRaw ?? ''),
              onExport: _exportPdf,
            ),
            _AnalysisTab(analysis: analysis),
          ],
        ),
      ),
    );
  }
}

class _ResultTab extends StatelessWidget {
  const _ResultTab({required this.text, required this.onCopy, required this.onShare, required this.onExport});

  final String text;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: Text(text))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: onCopy, icon: const Icon(Icons.copy)),
              IconButton(onPressed: onShare, icon: const Icon(Icons.share)),
              IconButton(onPressed: onExport, icon: const Icon(Icons.picture_as_pdf)),
            ],
          )
        ],
      ),
    );
  }
}

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab({required this.analysis});

  final Map<String, dynamic> analysis;

  @override
  Widget build(BuildContext context) {
    final keyTopics = (analysis['key_topics'] as List<dynamic>? ?? []).join(', ');
    final decisions = (analysis['decisions'] as List<dynamic>? ?? []);
    final actionItems = (analysis['action_items'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Resumo executivo', style: Theme.of(context).textTheme.titleMedium),
        Text(analysis['executive_summary']?.toString() ?? ''),
        const SizedBox(height: 12),
        Text('Tópicos-chave', style: Theme.of(context).textTheme.titleMedium),
        Text(keyTopics),
        const SizedBox(height: 12),
        Text('Decisões', style: Theme.of(context).textTheme.titleMedium),
        ...decisions.map((item) {
          final data = item as Map<String, dynamic>;
          return ListTile(
            title: Text(data['decision']?.toString() ?? ''),
            subtitle: Text(data['evidence']?.toString() ?? ''),
          );
        }),
        const SizedBox(height: 12),
        Text('Ações', style: Theme.of(context).textTheme.titleMedium),
        ...actionItems.map((item) {
          final data = item as Map<String, dynamic>;
          return ListTile(
            title: Text(data['task']?.toString() ?? ''),
            subtitle: Text('Dono: ${data['owner']} | Prioridade: ${data['priority']} | Prazo: ${data['due_date']}'),
          );
        }),
        const SizedBox(height: 12),
        Text('Perguntas em aberto', style: Theme.of(context).textTheme.titleMedium),
        Text((analysis['open_questions'] as List<dynamic>? ?? []).join('\n')),
        const SizedBox(height: 12),
        Text('Insights', style: Theme.of(context).textTheme.titleMedium),
        Text((analysis['insights'] as List<dynamic>? ?? []).join('\n')),
        const SizedBox(height: 12),
        Text('Próximos passos', style: Theme.of(context).textTheme.titleMedium),
        Text((analysis['next_steps'] as List<dynamic>? ?? []).join('\n')),
        const SizedBox(height: 12),
        Text('Tags', style: Theme.of(context).textTheme.titleMedium),
        Text((analysis['tags'] as List<dynamic>? ?? []).join(', ')),
      ],
    );
  }
}
