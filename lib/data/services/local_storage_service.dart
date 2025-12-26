import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/logbook_entry.dart';

/// Local storage service using Hive
class LocalStorageService {
  static const String _profileBoxName = 'profiles';
  static const String _logbookBoxName = 'logbook_entries';
  static const String _currentUserKey = 'current_user';

  late Box<UserProfile> _profileBox;
  late Box<LogbookEntry> _logbookBox;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LogbookEntryAdapter());
    }

    // Open boxes
    _profileBox = await Hive.openBox<UserProfile>(_profileBoxName);
    _logbookBox = await Hive.openBox<LogbookEntry>(_logbookBoxName);
  }

  // ===================== PROFILE OPERATIONS =====================

  /// Save user profile locally
  Future<void> saveProfile(UserProfile profile) async {
    await _profileBox.put(profile.id, profile);
    await _profileBox.put(_currentUserKey, profile);
  }

  /// Get current user profile
  UserProfile? getCurrentProfile() {
    return _profileBox.get(_currentUserKey);
  }

  /// Get profile by ID
  UserProfile? getProfile(String id) {
    return _profileBox.get(id);
  }

  /// Clear current user data (for logout)
  Future<void> clearCurrentUser() async {
    await _profileBox.delete(_currentUserKey);
  }

  // ===================== LOGBOOK OPERATIONS =====================

  /// Save a logbook entry locally
  Future<void> saveEntry(LogbookEntry entry) async {
    await _logbookBox.put(entry.id, entry);
  }

  /// Get all logbook entries for a user (excluding deleted)
  List<LogbookEntry> getEntriesForUser(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Get entry by ID
  LogbookEntry? getEntry(String id) {
    return _logbookBox.get(id);
  }

  /// Get all unsynced entries (draft or queued)
  List<LogbookEntry> getUnsyncedEntries(String userId) {
    return _logbookBox.values
        .where((entry) =>
            entry.userId == userId &&
            (entry.status == 'draft' || entry.status == 'queued'))
        .toList();
  }

  /// Update entry status
  Future<void> updateEntryStatus(String entryId, String status) async {
    final entry = _logbookBox.get(entryId);
    if (entry != null) {
      final updated = entry.copyWith(status: status);
      await _logbookBox.put(entryId, updated);
    }
  }

  /// Hard delete an entry (for unsynced entries)
  Future<void> deleteEntry(String id) async {
    await _logbookBox.delete(id);
  }
  
  /// Soft delete an entry (for synced entries)
  Future<void> softDeleteEntry(String id) async {
    final entry = _logbookBox.get(id);
    if (entry != null) {
      final updated = entry.copyWith(isDeleted: true, status: 'draft');
      await _logbookBox.put(id, updated);
    }
  }
  
  /// Update an entry
  Future<void> updateEntry(LogbookEntry entry) async {
    final updated = entry.copyWith(
      updatedAt: DateTime.now(),
      status: entry.isSynced ? 'draft' : entry.status, // Mark as draft if it was synced (needs re-sync)
    );
    await _logbookBox.put(entry.id, updated);
  }

  /// Clear all entries for a user
  Future<void> clearEntriesForUser(String userId) async {
    final entriesToDelete = _logbookBox.values
        .where((entry) => entry.userId == userId)
        .map((entry) => entry.id)
        .toList();

    for (final id in entriesToDelete) {
      await _logbookBox.delete(id);
    }
  }

  /// Get total count of entries (excluding deleted)
  int getEntryCount(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .length;
  }

  /// Bulk save entries (for sync)
  Future<void> saveEntries(List<LogbookEntry> entries) async {
    for (final entry in entries) {
      await _logbookBox.put(entry.id, entry);
    }
  }

  // ===================== ANALYTICS =====================

  /// Get total flight hours for a user (excluding deleted)
  double getTotalHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.totalHours);
  }

  /// Get dual hours for a user (excluding deleted)
  double getDualHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.dualHours);
  }

  /// Get solo hours for a user (excluding deleted)
  double getSoloHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.soloHours);
  }

  /// Get hours in last N days (excluding deleted)
  double getHoursInLastDays(String userId, int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted && entry.date.isAfter(cutoffDate))
        .fold(0.0, (sum, entry) => sum + entry.totalHours);
  }
  
  /// Get night hours for a user (excluding deleted)
  double getNightHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.nightHours);
  }
  
  /// Get PIC hours for a user (excluding deleted)
  double getPicHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.picHours);
  }
  
  /// Get SIC hours for a user (excluding deleted)
  double getSicHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.sicHours);
  }
  
  /// Get Cross-Country hours for a user (excluding deleted)
  double getXcHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.xcHours);
  }
  
  /// Get Instrument hours for a user (excluding deleted)
  double getInstrumentHours(String userId) {
    return _logbookBox.values
        .where((entry) => entry.userId == userId && !entry.isDeleted)
        .fold(0.0, (sum, entry) => sum + entry.instrumentHours);
  }
  
  /// Get flight type breakdown (count of flights per type, excluding deleted)
  Map<String, int> getFlightTypeBreakdown(String userId) {
    final breakdown = <String, int>{};
    for (final entry in _logbookBox.values.where((e) => e.userId == userId && !e.isDeleted)) {
      for (var type in entry.flightType) {
        // Normalize all variants to "Cross-Country"
        if (type == 'XC' || type.toLowerCase() == 'cross-country') {
          type = 'Cross-Country';
        }
        breakdown[type] = (breakdown[type] ?? 0) + 1;
      }
    }
    return breakdown;
  }

  /// Get hours breakdown by month (last 6 months)
  Map<String, double> getMonthlyHours(String userId) {
    final now = DateTime.now();
    final months = <String, double>{};
    
    // Initialize last 6 months with 0 (handle year rollover)
    for (int i = 5; i >= 0; i--) {
      // Subtract months properly using DateTime
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthNum = targetDate.month;
      final yearStr = targetDate.year.toString().length >= 4 
          ? targetDate.year.toString().substring(2) 
          : targetDate.year.toString();
      final key = '${_getMonthName(monthNum)} $yearStr';
      months[key] = 0;
    }
    
    // Calculate 6 months ago date
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    
    // Sum hours per month (excluding deleted)
    for (final entry in _logbookBox.values.where((e) => e.userId == userId && !e.isDeleted)) {
      final entryMonth = DateTime(entry.date.year, entry.date.month, 1);
      
      if (entryMonth.isAfter(sixMonthsAgo.subtract(const Duration(days: 1)))) {
        final monthNum = entryMonth.month;
        final yearStr = entryMonth.year.toString().length >= 4 
            ? entryMonth.year.toString().substring(2) 
            : entryMonth.year.toString();
        final key = '${_getMonthName(monthNum)} $yearStr';
        if (months.containsKey(key)) {
          months[key] = months[key]! + entry.totalHours;
        }
      }
    }
    
    return months;
  }
  
  String _getMonthName(int month) {
    // Handle any month value including those from year rollover
    final normalizedMonth = ((month - 1) % 12) + 1;
    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return monthNames[normalizedMonth];
  }

  // ===================== SEARCH & FILTER =====================

  /// Search entries by aircraft registration or route
  List<LogbookEntry> searchEntries(String userId, String query) {
    final lowerQuery = query.toLowerCase();
    return _logbookBox.values
        .where((entry) =>
            entry.userId == userId &&
            (entry.aircraftReg.toLowerCase().contains(lowerQuery) ||
                entry.depIcao.toLowerCase().contains(lowerQuery) ||
                entry.arrIcao.toLowerCase().contains(lowerQuery)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Filter entries by flight type
  List<LogbookEntry> filterByFlightType(String userId, String flightType) {
    return _logbookBox.values
        .where((entry) =>
            entry.userId == userId && entry.flightType.contains(flightType))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Filter entries by date range
  List<LogbookEntry> filterByDateRange(
      String userId, DateTime startDate, DateTime endDate) {
    return _logbookBox.values
        .where((entry) =>
            entry.userId == userId &&
            entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
