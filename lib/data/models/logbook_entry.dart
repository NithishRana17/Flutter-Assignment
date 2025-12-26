import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'logbook_entry.g.dart';

/// Logbook entry model for flight records
@HiveType(typeId: 1)
class LogbookEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String depIcao; // Departure ICAO code

  @HiveField(4)
  final String arrIcao; // Arrival ICAO code

  @HiveField(5)
  final String aircraftReg; // Aircraft registration

  @HiveField(6)
  final List<String> flightType; // ['Dual', 'Solo', 'PIC', etc.]

  @HiveField(7)
  final DateTime startTime;

  @HiveField(8)
  final DateTime endTime;

  @HiveField(9)
  final double totalHours;

  @HiveField(10)
  final double picHours; // Pilot in Command hours

  @HiveField(11)
  final double dualHours; // Dual Received (student receiving instruction)

  @HiveField(12)
  final double nightHours;

  @HiveField(13)
  final double xcHours; // Cross-country hours

  @HiveField(14)
  final String? remarks;

  @HiveField(15)
  final List<String> tags;

  @HiveField(16)
  final String status; // 'draft' | 'queued' | 'synced'

  @HiveField(17)
  final DateTime createdAt;

  @HiveField(18)
  final DateTime updatedAt;
  
  @HiveField(19)
  final bool isDeleted; // Soft delete flag
  
  @HiveField(20)
  final double dualGivenHours; // Dual Given (instructor giving instruction)
  
  @HiveField(21)
  final double instrumentHours; // Instrument (IMC or Simulated) hours
  
  @HiveField(22)
  final double soloHours; // Solo flight hours (student flying alone)
  
  @HiveField(23)
  final double sicHours; // Second in Command hours

  LogbookEntry({
    String? id,
    required this.userId,
    required this.date,
    required this.depIcao,
    required this.arrIcao,
    required this.aircraftReg,
    required this.flightType,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    this.picHours = 0,
    this.sicHours = 0,
    this.dualHours = 0,
    this.dualGivenHours = 0,
    this.soloHours = 0,
    this.nightHours = 0,
    this.xcHours = 0,
    this.instrumentHours = 0,
    this.remarks,
    this.tags = const [],
    this.status = 'draft',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from Supabase response
  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    return LogbookEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      depIcao: json['dep_icao'] as String,
      arrIcao: json['arr_icao'] as String,
      aircraftReg: json['aircraft_reg'] as String,
      flightType: (json['flight_type'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      startTime: _parseTime(json['start_time'] as String, json['date'] as String),
      endTime: _parseTime(json['end_time'] as String, json['date'] as String),
      totalHours: (json['total_hours'] as num).toDouble(),
      picHours: (json['pic_hours'] as num?)?.toDouble() ?? 0,
      sicHours: (json['sic_hours'] as num?)?.toDouble() ?? 0,
      dualHours: (json['dual_hours'] as num?)?.toDouble() ?? 0,
      dualGivenHours: (json['dual_given_hours'] as num?)?.toDouble() ?? 0,
      soloHours: (json['solo_hours'] as num?)?.toDouble() ?? 0,
      nightHours: (json['night_hours'] as num?)?.toDouble() ?? 0,
      xcHours: (json['xc_hours'] as num?)?.toDouble() ?? 0,
      instrumentHours: (json['instrument_hours'] as num?)?.toDouble() ?? 0,
      remarks: json['remarks'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: json['status'] as String? ?? 'synced',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  /// Parse time string to DateTime
  static DateTime _parseTime(String timeStr, String dateStr) {
    final datePart = dateStr.split('T')[0];
    final timePart = timeStr.split('.')[0]; // Remove microseconds if present
    return DateTime.parse('$datePart $timePart');
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0],
      'dep_icao': depIcao.toUpperCase(),
      'arr_icao': arrIcao.toUpperCase(),
      'aircraft_reg': aircraftReg.toUpperCase(),
      'flight_type': flightType,
      'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
      'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
      'total_hours': totalHours,
      'pic_hours': picHours,
      'sic_hours': sicHours,
      'dual_hours': dualHours,
      'dual_given_hours': dualGivenHours,
      'solo_hours': soloHours,
      'night_hours': nightHours,
      'xc_hours': xcHours,
      'instrument_hours': instrumentHours,
      'remarks': remarks,
      'tags': tags.isEmpty ? null : tags,
      'status': status,
      'is_deleted': isDeleted,
      // Let database handle timestamps
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  LogbookEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? depIcao,
    String? arrIcao,
    String? aircraftReg,
    List<String>? flightType,
    DateTime? startTime,
    DateTime? endTime,
    double? totalHours,
    double? picHours,
    double? sicHours,
    double? dualHours,
    double? dualGivenHours,
    double? soloHours,
    double? nightHours,
    double? xcHours,
    double? instrumentHours,
    String? remarks,
    List<String>? tags,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return LogbookEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      depIcao: depIcao ?? this.depIcao,
      arrIcao: arrIcao ?? this.arrIcao,
      aircraftReg: aircraftReg ?? this.aircraftReg,
      flightType: flightType ?? this.flightType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalHours: totalHours ?? this.totalHours,
      picHours: picHours ?? this.picHours,
      sicHours: sicHours ?? this.sicHours,
      dualHours: dualHours ?? this.dualHours,
      dualGivenHours: dualGivenHours ?? this.dualGivenHours,
      soloHours: soloHours ?? this.soloHours,
      nightHours: nightHours ?? this.nightHours,
      xcHours: xcHours ?? this.xcHours,
      instrumentHours: instrumentHours ?? this.instrumentHours,
      remarks: remarks ?? this.remarks,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Get route string (e.g., "VOMM → VOBL")
  String get route => '$depIcao → $arrIcao';

  /// Check if this entry is synced
  bool get isSynced => status == 'synced';

  /// Check if this entry is a draft
  bool get isDraft => status == 'draft';

  /// Check if this entry is queued for sync
  bool get isQueued => status == 'queued';
}
