import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import '../models/logbook_entry.dart';

/// Supabase service for remote operations
class SupabaseService {
  late final SupabaseClient _client;

  /// Initialize Supabase client
  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  /// Get Supabase client instance
  SupabaseClient get client => _client;

  // ===================== AUTH OPERATIONS =====================

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ===================== PROFILE OPERATIONS =====================

  /// Get user profile
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create or update user profile (uses upsert to handle both cases)
  Future<UserProfile?> updateProfile(UserProfile profile) async {
    try {
      // Use upsert to create if doesn't exist, update if exists
      final response = await _client
          .from('profiles')
          .upsert(profile.toJson())
          .select()
          .single();
      print('DEBUG: Profile upserted successfully for ${profile.id}');
      return UserProfile.fromJson(response);
    } catch (e) {
      print('ERROR: Failed to upsert profile: $e');
      rethrow;
    }
  }
  
  /// Ensure profile exists in database (create if missing)
  Future<bool> ensureProfileExists(String userId, String email, {String? fullName}) async {
    try {
      // Check if profile exists
      final existing = await getProfile(userId);
      if (existing != null) {
        print('DEBUG: Profile already exists for $userId');
        return true;
      }
      
      // Create profile
      await _client.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
      });
      print('DEBUG: Created new profile for $userId');
      return true;
    } catch (e) {
      print('ERROR: Failed to ensure profile exists: $e');
      return false;
    }
  }

  // ===================== LOGBOOK OPERATIONS =====================

  /// Get all logbook entries for current user (excluding deleted)
  Future<List<LogbookEntry>> getEntries() async {
    if (currentUser == null) return [];

    try {
      final response = await _client
          .from('logbook_entries')
          .select()
          .eq('user_id', currentUser!.id)
          .neq('is_deleted', true)
          .order('date', ascending: false);

      return (response as List)
          .map((json) => LogbookEntry.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get IDs of entries that are marked as deleted on server
  Future<List<String>> getDeletedEntryIds() async {
    if (currentUser == null) return [];

    try {
      final response = await _client
          .from('logbook_entries')
          .select('id')
          .eq('user_id', currentUser!.id)
          .eq('is_deleted', true);

      return (response as List)
          .map((json) => json['id'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }


  /// Get a single entry by ID
  Future<LogbookEntry?> getEntry(String entryId) async {
    try {
      final response = await _client
          .from('logbook_entries')
          .select()
          .eq('id', entryId)
          .single();
      return LogbookEntry.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create a new logbook entry
  Future<LogbookEntry?> createEntry(LogbookEntry entry) async {
    try {
      final response = await _client
          .from('logbook_entries')
          .insert(entry.toJson())
          .select()
          .single();
      return LogbookEntry.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing entry
  Future<LogbookEntry?> updateEntry(LogbookEntry entry) async {
    try {
      final response = await _client
          .from('logbook_entries')
          .update(entry.toJson())
          .eq('id', entry.id)
          .select()
          .single();
      return LogbookEntry.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(String entryId) async {
    await _client.from('logbook_entries').delete().eq('id', entryId);
  }

  /// Sync a single entry (upsert)
  Future<LogbookEntry?> syncEntry(LogbookEntry entry) async {
    try {
      // Debug: Check authentication state
      final user = currentUser;
      final session = currentSession;
      print('DEBUG: Auth state - user: ${user?.id}, session valid: ${session != null}');
      print('DEBUG: Entry user_id: ${entry.userId}');
      
      // Verify user_id matches authenticated user
      if (user == null) {
        print('ERROR: Not authenticated - cannot sync');
        throw Exception('Not authenticated');
      }
      
      if (entry.userId != user.id) {
        print('ERROR: User ID mismatch - entry: ${entry.userId}, auth: ${user.id}');
        throw Exception('User ID mismatch');
      }
      
      final syncedEntry = entry.copyWith(status: 'synced');
      final jsonData = syncedEntry.toJson();
      
      // Debug: Print the JSON being sent
      print('DEBUG: Syncing entry ${entry.id}');
      print('DEBUG: JSON data: $jsonData');
      
      final response = await _client
          .from('logbook_entries')
          .upsert(jsonData)
          .select()
          .single();
      
      print('DEBUG: Sync successful for ${entry.id}');
      return LogbookEntry.fromJson(response);
    } catch (e, stackTrace) {
      print('ERROR: Failed to sync entry ${entry.id}');
      print('ERROR: Exception: $e');
      print('ERROR: StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Bulk sync entries
  Future<List<LogbookEntry>> syncEntries(List<LogbookEntry> entries) async {
    if (entries.isEmpty) return [];

    try {
      final syncedEntries = entries
          .map((e) => e.copyWith(status: 'synced').toJson())
          .toList();

      final response = await _client
          .from('logbook_entries')
          .upsert(syncedEntries)
          .select();

      return (response as List)
          .map((json) => LogbookEntry.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ===================== REALTIME OPERATIONS =====================

  /// Subscribe to realtime changes on logbook_entries table
  /// Returns a RealtimeChannel that can be used to unsubscribe
  RealtimeChannel subscribeToLogbookChanges({
    required String userId,
    required Function(List<Map<String, dynamic>>) onInsert,
    required Function(List<Map<String, dynamic>>) onUpdate,
    required Function(List<Map<String, dynamic>>) onDelete,
  }) {
    final channel = _client.channel('logbook_realtime_$userId');
    
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'logbook_entries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('REALTIME: Insert event received');
          onInsert([payload.newRecord]);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'logbook_entries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('REALTIME: Update event received');
          onUpdate([payload.newRecord]);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'logbook_entries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('REALTIME: Delete event received');
          onDelete([payload.oldRecord]);
        },
      )
      .subscribe((status, [error]) {
        print('REALTIME: Channel status: $status');
        if (error != null) {
          print('REALTIME: Error: $error');
        }
      });

    return channel;
  }

  /// Unsubscribe from a realtime channel
  Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
