// FIXIS PRO v1.1.1 - Bootstrap + Fast Auth Gate seguro
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/theme.dart';
import 'features/auth/screens/auth_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY en el archivo .env.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: FixisProApp(),
    ),
  );
}

class FixisProApp extends StatelessWidget {
  const FixisProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIXIS PRO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGateScreen(),
      },
    );
  }
}
