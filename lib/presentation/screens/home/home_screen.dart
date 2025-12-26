import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../logbook/logbook_list_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _wasOffline = false;
  dynamic _realtimeChannel;

  @override
  void initState() {
    super.initState();
    // Load entries and try auto-sync after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
      _syncOnLaunch();
      _setupRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _cleanupRealtimeSubscription();
    super.dispose();
  }


  /// Setup realtime subscription for live updates
  void _setupRealtimeSubscription() {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id;
    if (userId == null) return;

    final supabase = ref.read(supabaseServiceProvider);
    
    // Update status to connecting
    ref.read(realtimeStatusProvider.notifier).state = RealtimeStatus.connecting;
    
    _realtimeChannel = supabase.subscribeToLogbookChanges(
      userId: userId,
      onInsert: (data) async {
        print('REALTIME: New entry inserted, refreshing...');
        await _loadEntriesAsync();
      },
      onUpdate: (data) async {
        print('REALTIME: Entry updated, refreshing...');
        await _loadEntriesAsync();
      },
      onDelete: (data) async {
        print('REALTIME: Entry deleted, refreshing...');
        await _loadEntriesAsync();
      },
    );
    
    // Update status to connected after subscription
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(realtimeStatusProvider.notifier).state = RealtimeStatus.connected;
      }
    });
  }

  /// Cleanup realtime subscription
  void _cleanupRealtimeSubscription() {
    if (_realtimeChannel != null) {
      final supabase = ref.read(supabaseServiceProvider);
      supabase.unsubscribeChannel(_realtimeChannel);
      ref.read(realtimeStatusProvider.notifier).state = RealtimeStatus.disconnected;
    }
  }

  
  /// Try to sync pending entries when app launches
  Future<void> _syncOnLaunch() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id;
    if (userId == null) return;
    
    // Check if there are pending entries
    final localStorage = ref.read(localStorageServiceProvider);
    final unsyncedEntries = localStorage.getUnsyncedEntries(userId);
    if (unsyncedEntries.isEmpty) return;
    
    // Check if online
    final syncService = ref.read(syncServiceProvider);
    final isOnline = await syncService.isOnline;
    if (!isOnline) {
      _wasOffline = true;
      return;
    }
    
    // Perform auto-sync
    print('DEBUG: Auto-syncing ${unsyncedEntries.length} entries on app launch');
    await _performAutoSync(userId);
  }

  void _loadEntries() {
    final authState = ref.read(authNotifierProvider);
    if (authState.profile != null) {
      ref
          .read(logbookNotifierProvider(authState.profile!.id).notifier)
          .loadEntries();
      // Also invalidate analytics so it recalculates
      ref.invalidate(analyticsProvider(authState.profile!.id));
    }
  }

  /// Async version that waits for entries to load before invalidating analytics
  Future<void> _loadEntriesAsync() async {
    final authState = ref.read(authNotifierProvider);
    if (authState.profile != null) {
      await ref
          .read(logbookNotifierProvider(authState.profile!.id).notifier)
          .loadEntries();
      // Invalidate analytics AFTER entries are loaded and local storage is updated
      ref.invalidate(analyticsProvider(authState.profile!.id));
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id;
    
    if (userId != null && isOnline && _wasOffline) {
      // Device just came online - trigger auto-sync
      _performAutoSync(userId);
    }
    _wasOffline = !isOnline;
  }
  
  Future<void> _performAutoSync(String userId) async {
    final autoSync = ref.read(autoSyncProvider(userId).notifier);
    await autoSync.onConnectivityRestored();
    
    final syncState = ref.read(autoSyncProvider(userId));
    if (syncState.lastSyncMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(syncState.lastSyncMessage!)),
            ],
          ),
          backgroundColor: syncState.pendingCount == 0 
              ? AppColors.success 
              : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      // Refresh entries after auto-sync
      _loadEntries();
      ref.invalidate(analyticsProvider(userId));
    }
  }

  Future<void> _navigateToAddFlight() async {
    final result = await context.push('/add-flight');
    // Refresh entries after returning from add flight screen
    if (result != null || true) {
      // Always refresh when coming back
      _loadEntries();
      // Also refresh analytics
      final authState = ref.read(authNotifierProvider);
      if (authState.profile != null) {
        ref.invalidate(analyticsProvider(authState.profile!.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.profile?.id ?? '';
    
    // Listen to connectivity changes for auto-sync
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (previous, next) {
      next.whenData((isOnline) {
        _handleConnectivityChange(isOnline);
      });
    });
    
    // Get current connectivity status
    final connectivityAsync = ref.watch(connectivityStreamProvider);
    final isOnline = connectivityAsync.valueOrNull ?? true;

    final screens = [
      LogbookListScreen(userId: userId),
      AnalyticsScreen(userId: userId),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          // Offline indicator
          if (!isOnline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppColors.warning,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  bottom: 8,
                  left: 16,
                  right: 16,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Offline - Changes will sync when online',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFlight,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.flight_outlined,
                    activeIcon: Icons.flight,
                    label: 'Logbook',
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.analytics_outlined,
                    activeIcon: Icons.analytics,
                    label: 'Analytics',
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live indicator widget that shows realtime connection status
class _LiveIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeStatus = ref.watch(realtimeStatusProvider);
    
    if (realtimeStatus != RealtimeStatus.connected) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
