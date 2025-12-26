import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

/// Splash screen shown during app initialization
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Small delay to show splash
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      // Check auth state
      await ref.read(authNotifierProvider.notifier).checkAuthState();
      
      if (!mounted) return;
      
      final authState = ref.read(authNotifierProvider);
      
      if (authState.status == AuthStatus.authenticated) {
        // User is logged in
        if (authState.profile?.isComplete == true) {
          context.go('/home');
        } else {
          context.go('/profile-setup');
        }
      } else {
        // Not logged in - show login
        context.go('/login');
      }
    } catch (e) {
      // On any error, go to login
      debugPrint('Auth check failed: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flight,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            const Text(
              'Logbook Lite',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilot Logbook',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Authenticating...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
