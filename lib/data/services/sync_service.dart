import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/logbook_entry.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

/// Sync service for offline-first data synchronization
class SyncService {
  final LocalStorageService _localStorage;
  final SupabaseService _supabase;
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService({
    required LocalStorageService localStorage,
    required SupabaseService supabase,
  })  : _localStorage = localStorage,
        _supabase = supabase;

  /// Check if device is online
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Get the supabase service for remote operations
  SupabaseService get supabaseService => _supabase;

  /// Start listening for connectivity changes
  void startListening(String userId) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        if (!results.contains(ConnectivityResult.none)) {
          // Device came online, sync pending entries
          await syncPendingEntries(userId);
        }
      },
    );
  }
  
  /// Stream of connectivity status (true = online, false = offline)
  Stream<bool> get connectivityStream => _connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );

  /// Stop listening for connectivity changes
  void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Sync all pending (unsynced) entries
  Future<SyncResult> syncPendingEntries(String userId) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    if (!await isOnline) {
      return SyncResult(
        success: false,
        message: 'Device is offline',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    _isSyncing = true;
    int syncedCount = 0;
    int failedCount = 0;
    final failedEntries = <String>[];

    try {
      // Get all unsynced entries
      final unsyncedEntries = _localStorage.getUnsyncedEntries(userId);

      if (unsyncedEntries.isEmpty) {
        return SyncResult(
          success: true,
          message: 'No entries to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      // Mark entries as queued
      for (final entry in unsyncedEntries) {
        await _localStorage.updateEntryStatus(entry.id, 'queued');
      }

      String? lastError;
      
      // Sync each entry
      for (final entry in unsyncedEntries) {
        try {
          final syncedEntry = await _supabase.syncEntry(entry);
          if (syncedEntry != null) {
            // Update local storage with synced status
            await _localStorage.saveEntry(syncedEntry);
            syncedCount++;
          } else {
            // Revert to draft status
            await _localStorage.updateEntryStatus(entry.id, 'draft');
            failedCount++;
            failedEntries.add(entry.id);
          }
        } catch (e) {
          // Capture error message and revert to draft status
          lastError = e.toString();
          print('SYNC ERROR: $lastError');
          await _localStorage.updateEntryStatus(entry.id, 'draft');
          failedCount++;
          failedEntries.add(entry.id);
        }
      }

      return SyncResult(
        success: failedCount == 0,
        message: failedCount == 0
            ? 'Successfully synced $syncedCount entries'
            : 'Failed: ${lastError ?? "$failedCount entries failed"}',
        syncedCount: syncedCount,
        failedCount: failedCount,
        failedEntryIds: failedEntries,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Retry syncing a specific entry
  Future<bool> retrySyncEntry(LogbookEntry entry) async {
    if (!await isOnline) return false;

    try {
      await _localStorage.updateEntryStatus(entry.id, 'queued');
      final syncedEntry = await _supabase.syncEntry(entry);
      if (syncedEntry != null) {
        await _localStorage.saveEntry(syncedEntry);
        return true;
      }
      await _localStorage.updateEntryStatus(entry.id, 'draft');
      return false;
    } catch (e) {
      await _localStorage.updateEntryStatus(entry.id, 'draft');
      return false;
    }
  }

  /// Fetch and merge remote entries
  Future<void> fetchRemoteEntries(String userId) async {
    if (!await isOnline) return;

    try {
      final remoteEntries = await _supabase.getEntries();
      final localEntries = _localStorage.getEntriesForUser(userId);

      // Merge strategy: remote entries take precedence for synced items
      for (final remoteEntry in remoteEntries) {
        final localEntry = localEntries.firstWhere(
          (e) => e.id == remoteEntry.id,
          orElse: () => remoteEntry,
        );

        // If local entry is not a draft, use remote
        if (!localEntry.isDraft) {
          await _localStorage.saveEntry(remoteEntry);
        }
      }
    } catch (e) {
      // Silently fail, use local data
    }
  }

  /// Full sync (fetch remote + push local)
  Future<SyncResult> fullSync(String userId) async {
    if (!await isOnline) {
      return SyncResult(
        success: false,
        message: 'Device is offline',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    // First, fetch remote entries
    await fetchRemoteEntries(userId);

    // Then, push local pending entries
    return await syncPendingEntries(userId);
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> failedEntryIds;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
    this.failedEntryIds = const [],
  });
}
