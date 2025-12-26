import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/profile/profile_setup_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/add_flight/add_flight_screen.dart';
import '../presentation/screens/logbook/logbook_detail_screen.dart';
import '../presentation/screens/ai/captain_mave_screen.dart';
import '../data/models/logbook_entry.dart';

/// Helper to get entry by ID for Captain MAVE context
LogbookEntry? _getEntryById(ProviderRef<GoRouter> ref, String entryId) {
  final localStorage = ref.read(localStorageServiceProvider);
  return localStorage.getEntry(entryId);
}

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
/// App router configuration
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    // Refresh router when auth state changes - this triggers redirect without recreating router
    refreshListenable: GoRouterRefreshStream(ref.watch(authNotifierProvider.notifier).stream),
    redirect: (context, state) {
      // Read auth state inside redirect to avoid recreating entire router
      final authState = ref.read(authNotifierProvider);
      final authStatus = authState.status;
      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isProfileSetup = state.matchedLocation == '/profile-setup';
      final isSplash = state.matchedLocation == '/splash';

      // Allow splash screen to handle its own navigation
      if (isSplash) {
        return null;
      }

      // If still loading or initial, allow auth routes to stay (don't redirect during login attempt)
      if (authStatus == AuthStatus.initial || authStatus == AuthStatus.loading) {
        // If already on auth route, stay there (prevents page reload on sign in)
        if (isAuthRoute) {
          return null;
        }
        // Otherwise go to splash for initial load
        if (!isSplash) {
          return '/splash';
        }
        return null;
      }

      // If unauthenticated, only allow auth routes
      if (authStatus == AuthStatus.unauthenticated) {
        if (!isAuthRoute) {
          return '/login';
        }
        return null;
      }

      // At this point, user is authenticated
      
      // If authenticated with complete profile and on auth route, go to home
      if (isAuthenticated && 
          authState.profile?.isComplete == true &&
          isAuthRoute) {
        return '/home';
      }
      
      // If authenticated but profile is not complete, force to profile-setup
      if (isAuthenticated && authState.profile?.isComplete != true) {
        if (!isProfileSetup) {
          return '/profile-setup';
        }
        return null;
      }

      // Authenticated with complete profile - allow access to non-auth routes
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/add-flight',
        name: 'add-flight',
        builder: (context, state) => const AddFlightScreen(),
      ),
      GoRoute(
        path: '/flight/:id',
        name: 'flight-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LogbookDetailScreen(entryId: id);
        },
      ),
      GoRoute(
        path: '/edit-flight/:id',
        name: 'edit-flight',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddFlightScreen(editEntryId: id);
        },
      ),
      GoRoute(
        path: '/captain-mave',
        name: 'captain-mave',
        builder: (context, state) {
          final entryId = state.uri.queryParameters['entryId'];
          return CaptainMaveScreen(
            contextFlight: entryId != null ? _getEntryById(ref, entryId) : null,
          );
        },
      ),
    ],
  );
});
