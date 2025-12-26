import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/supabase_service.dart';
import 'providers/providers.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Ignore error if .env file is missing (e.g. in CI/CD or production if vars are set otherwise)
    // But helpful to log for debugging if needed
    debugPrint('Note: .env file not loaded: $e');
  }

  // Initialize services
  final localStorage = LocalStorageService();
  await localStorage.init();

  final supabase = SupabaseService();
  await supabase.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
        supabaseServiceProvider.overrideWithValue(supabase),
      ],
      child: const LogbookLiteApp(),
    ),
  );
}

class LogbookLiteApp extends ConsumerStatefulWidget {
  const LogbookLiteApp({super.key});

  @override
  ConsumerState<LogbookLiteApp> createState() => _LogbookLiteAppState();
}

class _LogbookLiteAppState extends ConsumerState<LogbookLiteApp> {
  @override
  void initState() {
    super.initState();
    // Check auth state on app start
    Future.microtask(() {
      ref.read(authNotifierProvider.notifier).checkAuthState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Logbook Lite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
