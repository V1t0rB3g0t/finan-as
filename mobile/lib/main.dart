import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/api_client.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const FinanAsApp());
}

class FinanAsApp extends StatelessWidget {
  const FinanAsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000';
    final apiClient = ApiClient(apiBase, storage: const FlutterSecureStorage());

    return MaterialApp(
      title: 'Base44 - Transcrição IA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: apiClient.token,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final token = snapshot.data;
          if (token == null) {
            return AuthScreen(apiClient: apiClient);
          }
          return HomeScreen(apiClient: apiClient);
        },
      ),
    );
  }
}
