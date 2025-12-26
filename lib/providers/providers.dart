import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/local_storage_service.dart';
import '../data/services/supabase_service.dart';
import '../data/services/sync_service.dart';
import '../data/services/gemini_service.dart';
import '../data/models/user_profile.dart';
import '../data/models/logbook_entry.dart';

// ===================== SERVICE PROVIDERS =====================

/// Local storage service provider
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    localStorage: ref.read(localStorageServiceProvider),
    supabase: ref.read(supabaseServiceProvider),
  );
});

/// Gemini AI service provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  service.init();
  return service;
});

// ===================== REALTIME PROVIDERS =====================

/// Realtime connection status enum
enum RealtimeStatus { disconnected, connecting, connected }

/// Realtime connection status provider
final realtimeStatusProvider = StateProvider<RealtimeStatus>((ref) {
  return RealtimeStatus.disconnected;
});

/// Sign out check result
class SignOutCheck {
  final bool canSignOut;
  final String? reason;
  final int unsyncedCount;
  
  SignOutCheck({
    required this.canSignOut,
    this.reason,
    this.unsyncedCount = 0,
  });
}

// ===================== AUTH PROVIDERS =====================

/// Auth state enum
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Auth state class
class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

/// Auth notifier for handling authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseService _supabase;
  final LocalStorageService _localStorage;

  AuthNotifier({
    required SupabaseService supabase,
    required LocalStorageService localStorage,
  })  : _supabase = supabase,
        _localStorage = localStorage,
        super(const AuthState());

  /// Check current auth state
  Future<void> checkAuthState() async {
    if (_supabase.isAuthenticated) {
      final user = _supabase.currentUser!;
      UserProfile? profile;

      // Always try to fetch from Supabase first to get latest profile data
      try {
        profile = await _supabase.getProfile(user.id);
        if (profile != null) {
          // Save latest profile to local storage
          await _localStorage.saveProfile(profile);
        }
      } catch (e) {
        print('DEBUG: Could not fetch profile from Supabase: $e');
        // Fall back to local storage if Supabase fails
        profile = _localStorage.getCurrentProfile();
      }

      // If still no profile, use local storage as last resort
      profile ??= _localStorage.getCurrentProfile();

      state = AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      // Get previous user ID (if any) to clear their data
      final previousProfile = _localStorage.getCurrentProfile();
      final previousUserId = previousProfile?.id;
      
      final response = await _supabase.signIn(email: email, password: password);

      if (response.user != null) {
        final newUserId = response.user!.id;
        
        // Clear old user's local entries if switching to a different user
        if (previousUserId != null && previousUserId != newUserId) {
          await _localStorage.clearEntriesForUser(previousUserId);
          print('DEBUG: Cleared local entries for previous user $previousUserId');
        }
        
        var profile = await _supabase.getProfile(response.user!.id);
        profile ??= UserProfile(
          id: response.user!.id,
          email: response.user!.email ?? email,
        );
        
        // Ensure profile exists in database (for foreign key constraints)
        await _supabase.ensureProfileExists(
          response.user!.id,
          response.user!.email ?? email,
          fullName: profile.fullName,
        );

        await _localStorage.saveProfile(profile);

        state = AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid credentials',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  /// Sign up with email and password
  /// Returns: 'success' if email confirmed, 'pending' if awaiting confirmation, 'error' on failure
  Future<String> signUp(String email, String password, {String? fullName}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final response = await _supabase.signUp(email: email, password: password);

      if (response.user != null) {
        // Check if email confirmation is required
        final emailConfirmed = response.user!.emailConfirmedAt != null;
        
        if (!emailConfirmed) {
          // Email confirmation is pending
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: null,
          );
          return 'pending';
        }
        
        // Email is confirmed, proceed with profile creation
        final profile = UserProfile(
          id: response.user!.id,
          email: response.user!.email ?? email,
          fullName: fullName,
        );

        await _localStorage.saveProfile(profile);
        
        // Ensure profile exists in Supabase database (for foreign key constraints)
        try {
          await _supabase.ensureProfileExists(
            response.user!.id,
            response.user!.email ?? email,
            fullName: fullName,
          );
        } catch (e) {
          print('Warning: Could not create profile in Supabase: $e');
        }

        state = AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
        return 'success';
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Sign up failed',
        );
        return 'error';
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _getErrorMessage(e),
      );
      return 'error';
    }
  }

  /// Update profile
  Future<bool> updateProfile({String? pilotType, String? licenseType, String? fullName}) async {
    if (state.profile == null) return false;

    try {
      final updatedProfile = state.profile!.copyWith(
        pilotType: pilotType,
        licenseType: licenseType,
        fullName: fullName,
      );

      await _localStorage.saveProfile(updatedProfile);

      // Try to sync with Supabase
      try {
        await _supabase.updateProfile(updatedProfile);
      } catch (_) {
        // Silently fail, local data is saved
      }

      state = state.copyWith(profile: updatedProfile);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if user can sign out (no unsynced data)
  Future<SignOutCheck> canSignOut() async {
    if (state.profile == null) return SignOutCheck(canSignOut: true);
    
    // Check for unsynced entries
    final unsyncedEntries = _localStorage.getUnsyncedEntries(state.profile!.id);
    if (unsyncedEntries.isNotEmpty) {
      return SignOutCheck(
        canSignOut: false,
        reason: 'You have ${unsyncedEntries.length} unsynced flight(s). Please sync before signing out.',
        unsyncedCount: unsyncedEntries.length,
      );
    }
    
    return SignOutCheck(canSignOut: true);
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.signOut();
    await _localStorage.clearCurrentUser();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Sign in errors
    if (errorStr.contains('invalid login credentials')) {
      return 'Invalid email or password. Please check and try again.';
    }
    if (errorStr.contains('user not found') || errorStr.contains('no user found')) {
      return 'No account found with this email. Please sign up first.';
    }
    
    // Sign up errors
    if (errorStr.contains('user already registered') || 
        errorStr.contains('already registered') ||
        errorStr.contains('already exists')) {
      return 'This email is already registered. Please sign in instead.';
    }
    
    // Email verification
    if (errorStr.contains('email not confirmed')) {
      return 'Please verify your email address to continue.';
    }
    
    // Network errors
    if (errorStr.contains('network') || 
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('timeout')) {
      return 'Network error. Please check your internet connection.';
    }
    
    // Rate limiting
    if (errorStr.contains('rate limit') || errorStr.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    
    // Password errors
    if (errorStr.contains('password') && errorStr.contains('weak')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    
    // Generic fallback
    print('Auth error (unhandled): $error');
    return 'Something went wrong. Please try again.';
  }
}

/// Auth notifier provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    supabase: ref.read(supabaseServiceProvider),
    localStorage: ref.read(localStorageServiceProvider),
  );
});

// ===================== LOGBOOK PROVIDERS =====================

/// Logbook state class
class LogbookState {
  final List<LogbookEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final String? searchQuery;
  final List<String> filterFlightTypes; // Changed to List for multi-select
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const LogbookState({
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery,
    this.filterFlightTypes = const [], // Default to empty list
    this.filterStartDate,
    this.filterEndDate,
  });

  LogbookState copyWith({
    List<LogbookEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    List<String>? filterFlightTypes,
    DateTime? filterStartDate,
    DateTime? filterEndDate,
    bool clearFilters = false,
    bool clearFlightTypeFilter = false,
    bool clearDateFilter = false,
    bool clearSearchQuery = false,
  }) {
    return LogbookState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: clearFilters || clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      filterFlightTypes: clearFilters || clearFlightTypeFilter ? [] : (filterFlightTypes ?? this.filterFlightTypes),
      filterStartDate: clearFilters || clearDateFilter ? null : (filterStartDate ?? this.filterStartDate),
      filterEndDate: clearFilters || clearDateFilter ? null : (filterEndDate ?? this.filterEndDate),
    );
  }

  /// Get filtered entries
  List<LogbookEntry> get filteredEntries {
    var result = entries;

    // Apply search
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      result = result.where((e) =>
          e.aircraftReg.toLowerCase().contains(query) ||
          e.depIcao.toLowerCase().contains(query) ||
          e.arrIcao.toLowerCase().contains(query)).toList();
    }

    // Apply flight type filter (matches ANY of the selected types)
    if (filterFlightTypes.isNotEmpty) {
      result = result.where((e) => 
          filterFlightTypes.any((type) => e.flightType.contains(type))).toList();
    }

    // Apply date range filter
    if (filterStartDate != null && filterEndDate != null) {
      result = result.where((e) =>
          e.date.isAfter(filterStartDate!.subtract(const Duration(days: 1))) &&
          e.date.isBefore(filterEndDate!.add(const Duration(days: 1)))).toList();
    }

    return result;
  }
}

/// Logbook notifier
class LogbookNotifier extends StateNotifier<LogbookState> {
  final LocalStorageService _localStorage;
  final SyncService _syncService;
  final String userId;

  LogbookNotifier({
    required LocalStorageService localStorage,
    required SyncService syncService,
    required this.userId,
  })  : _localStorage = localStorage,
        _syncService = syncService,
        super(const LogbookState()) {
    // Auto-load entries when notifier is created
    _initLoad();
  }

  /// Initial load of entries
  Future<void> _initLoad() async {
    final entries = _localStorage.getEntriesForUser(userId);
    state = state.copyWith(entries: entries, isLoading: false);
  }

  /// Load entries from local storage AND fetch from Supabase if online
  Future<void> loadEntries() async {
    state = state.copyWith(isLoading: true);

    try {
      // First load from local storage
      var entries = _localStorage.getEntriesForUser(userId);
      
      // Then try to fetch from Supabase and merge (if online)
      try {
        final isOnline = await _syncService.isOnline;
        if (isOnline) {
          final remoteEntries = await _syncService.supabaseService.getEntries();
          
          // Create a map of local entries by ID for quick lookup
          final localMap = {for (var e in entries) e.id: e};
          
          // Merge remote entries into local
        for (final remoteEntry in remoteEntries) {
          if (!localMap.containsKey(remoteEntry.id)) {
            // New entry from server - save locally
            await _localStorage.saveEntry(remoteEntry);
          } else {
            // Entry exists locally - update with remote data if remote is synced
            // This ensures edits from other devices are reflected
            final localEntry = localMap[remoteEntry.id]!;
            if (localEntry.status == 'pending') {
              // Local has pending changes - don't overwrite
              continue;
            }
            // Always update with remote synced data (handles edits from other devices)
            if (remoteEntry.status == 'synced') {
              await _localStorage.saveEntry(remoteEntry);
            }
          }
        }
          
          // Also remove entries that were deleted on server
          final deletedIds = await _syncService.supabaseService.getDeletedEntryIds();
          for (final deletedId in deletedIds) {
            if (localMap.containsKey(deletedId)) {
              await _localStorage.deleteEntry(deletedId);
              print('DEBUG: Removed locally deleted entry $deletedId');
            }
          }
          
          // Reload from local storage after merge
          entries = _localStorage.getEntriesForUser(userId);
        }
      } catch (e) {
        print('DEBUG: Could not fetch from Supabase: $e');
        // Continue with local entries only
      }
      
      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load entries',
      );
    }
  }

  /// Add a new entry (auto-syncs if online)
  Future<bool> addEntry(LogbookEntry entry) async {
    try {
      // Save locally first
      await _localStorage.saveEntry(entry);
      
      // Try to auto-sync immediately if online
      final isOnline = await _syncService.isOnline;
      if (isOnline) {
        // Attempt immediate sync
        await _syncService.syncPendingEntries(userId);
      }
      
      await loadEntries();
      return true;
    } catch (e) {
      // Even if sync fails, local save succeeded
      await loadEntries();
      return true;
    }
  }

  /// Update an entry (auto-syncs if online)
  Future<bool> updateEntry(LogbookEntry entry) async {
    try {
      // Use updateEntry which marks synced entries as draft for re-sync
      await _localStorage.updateEntry(entry);
      
      // Try to auto-sync immediately if online
      final isOnline = await _syncService.isOnline;
      if (isOnline) {
        await _syncService.syncPendingEntries(userId);
      }
      
      await loadEntries();
      return true;
    } catch (e) {
      await loadEntries();
      return false;
    }
  }

  /// Delete an entry (hard delete if unsynced, soft delete if synced)
  Future<bool> deleteEntry(String entryId) async {
    try {
      final entry = _localStorage.getEntry(entryId);
      if (entry == null) return false;
      
      if (entry.isSynced) {
        // Soft delete for synced entries
        await _localStorage.softDeleteEntry(entryId);
        
        // Try to sync the deletion if online
        final isOnline = await _syncService.isOnline;
        if (isOnline) {
          await _syncService.syncPendingEntries(userId);
        }
      } else {
        // Hard delete for unsynced (draft/queued) entries
        await _localStorage.deleteEntry(entryId);
      }
      
      await loadEntries();
      return true;
    } catch (e) {
      await loadEntries();
      return false;
    }
  }

  /// Sync entries with cloud
  Future<SyncResult> syncEntries() async {
    final result = await _syncService.syncPendingEntries(userId);
    await loadEntries();
    return result;
  }

  /// Retry syncing a specific entry
  Future<bool> retrySyncEntry(LogbookEntry entry) async {
    final success = await _syncService.retrySyncEntry(entry);
    await loadEntries();
    return success;
  }

  /// Set search query
  void setSearchQuery(String? query) {
    if (query == null) {
      state = state.copyWith(clearSearchQuery: true);
    } else {
      state = state.copyWith(searchQuery: query);
    }
  }

  /// Toggle flight type filter (multi-select: adds or removes type from list)
  void toggleFlightTypeFilter(String flightType) {
    final currentTypes = List<String>.from(state.filterFlightTypes);
    if (currentTypes.contains(flightType)) {
      currentTypes.remove(flightType);
    } else {
      currentTypes.add(flightType);
    }
    state = state.copyWith(filterFlightTypes: currentTypes);
  }

  /// Set all flight type filters at once
  void setFlightTypeFilters(List<String> flightTypes) {
    state = state.copyWith(filterFlightTypes: flightTypes);
  }

  /// Set date range filter
  void setDateRangeFilter(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      state = state.copyWith(clearDateFilter: true);
    } else {
      state = state.copyWith(
        filterStartDate: startDate,
        filterEndDate: endDate,
      );
    }
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(clearFilters: true);
  }
}

/// Logbook notifier provider (requires userId)
final logbookNotifierProvider =
    StateNotifierProvider.family<LogbookNotifier, LogbookState, String>(
  (ref, userId) {
    return LogbookNotifier(
      localStorage: ref.read(localStorageServiceProvider),
      syncService: ref.read(syncServiceProvider),
      userId: userId,
    );
  },
);

// ===================== ANALYTICS PROVIDERS =====================

/// Analytics data class
class AnalyticsData {
  final double totalHours;
  final double dualHours;
  final double soloHours;
  final double hoursLast7Days;
  final double hoursLast30Days;
  final int totalFlights;
  final Map<String, double> monthlyHours;
  final double nightHours;
  final double picHours;
  final double sicHours;
  final double xcHours;
  final double instrumentHours;
  final Map<String, int> flightTypeBreakdown;

  const AnalyticsData({
    this.totalHours = 0,
    this.dualHours = 0,
    this.soloHours = 0,
    this.hoursLast7Days = 0,
    this.hoursLast30Days = 0,
    this.totalFlights = 0,
    this.monthlyHours = const {},
    this.nightHours = 0,
    this.picHours = 0,
    this.sicHours = 0,
    this.xcHours = 0,
    this.instrumentHours = 0,
    this.flightTypeBreakdown = const {},
  });
}

/// Analytics provider
final analyticsProvider = Provider.family<AnalyticsData, String>((ref, userId) {
  final localStorage = ref.read(localStorageServiceProvider);

  return AnalyticsData(
    totalHours: localStorage.getTotalHours(userId),
    dualHours: localStorage.getDualHours(userId),
    soloHours: localStorage.getSoloHours(userId),
    hoursLast7Days: localStorage.getHoursInLastDays(userId, 7),
    hoursLast30Days: localStorage.getHoursInLastDays(userId, 30),
    totalFlights: localStorage.getEntryCount(userId),
    monthlyHours: localStorage.getMonthlyHours(userId),
    nightHours: localStorage.getNightHours(userId),
    picHours: localStorage.getPicHours(userId),
    sicHours: localStorage.getSicHours(userId),
    xcHours: localStorage.getXcHours(userId),
    instrumentHours: localStorage.getInstrumentHours(userId),
    flightTypeBreakdown: localStorage.getFlightTypeBreakdown(userId),
  );
});

// ===================== CONNECTIVITY PROVIDER =====================

/// Connectivity status provider (one-time check)
final isOnlineProvider = FutureProvider<bool>((ref) async {
  final syncService = ref.read(syncServiceProvider);
  return await syncService.isOnline;
});

/// Connectivity stream provider (for monitoring changes)
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final syncService = ref.read(syncServiceProvider);
  
  // Yield initial state
  yield await syncService.isOnline;
  
  // Listen to connectivity changes
  await for (final event in syncService.connectivityStream) {
    yield event;
  }
});

/// Auto-sync state
class AutoSyncState {
  final bool isSyncing;
  final String? lastSyncMessage;
  final int pendingCount;
  
  const AutoSyncState({
    this.isSyncing = false,
    this.lastSyncMessage,
    this.pendingCount = 0,
  });
  
  AutoSyncState copyWith({
    bool? isSyncing,
    String? lastSyncMessage,
    int? pendingCount,
  }) => AutoSyncState(
    isSyncing: isSyncing ?? this.isSyncing,
    lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
    pendingCount: pendingCount ?? this.pendingCount,
  );
}

/// Auto-sync notifier for background sync
class AutoSyncNotifier extends StateNotifier<AutoSyncState> {
  final SyncService _syncService;
  final LocalStorageService _localStorage;
  final String userId;
  
  AutoSyncNotifier({
    required SyncService syncService,
    required LocalStorageService localStorage,
    required this.userId,
  }) : _syncService = syncService,
       _localStorage = localStorage,
       super(const AutoSyncState());
  
  /// Called when connectivity changes to online
  Future<void> onConnectivityRestored() async {
    final unsyncedEntries = _localStorage.getUnsyncedEntries(userId);
    if (unsyncedEntries.isEmpty) return;
    
    state = state.copyWith(isSyncing: true, pendingCount: unsyncedEntries.length);
    
    try {
      final result = await _syncService.syncPendingEntries(userId);
      state = state.copyWith(
        isSyncing: false,
        lastSyncMessage: result.message,
        pendingCount: result.failedCount,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        lastSyncMessage: 'Auto-sync failed: $e',
      );
    }
  }
  
  /// Get pending sync count
  int get pendingCount => _localStorage.getUnsyncedEntries(userId).length;
}

/// Auto-sync notifier provider
final autoSyncProvider = StateNotifierProvider.family<AutoSyncNotifier, AutoSyncState, String>(
  (ref, userId) => AutoSyncNotifier(
    syncService: ref.read(syncServiceProvider),
    localStorage: ref.read(localStorageServiceProvider),
    userId: userId,
  ),
);
