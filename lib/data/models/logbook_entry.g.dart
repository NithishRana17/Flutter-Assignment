// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logbook_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogbookEntryAdapter extends TypeAdapter<LogbookEntry> {
  @override
  final int typeId = 1;

  @override
  LogbookEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogbookEntry(
      id: fields[0] as String?,
      userId: fields[1] as String,
      date: fields[2] as DateTime,
      depIcao: fields[3] as String,
      arrIcao: fields[4] as String,
      aircraftReg: fields[5] as String,
      flightType: (fields[6] as List).cast<String>(),
      startTime: fields[7] as DateTime,
      endTime: fields[8] as DateTime,
      totalHours: fields[9] as double,
      picHours: fields[10] as double,
      dualHours: fields[11] as double,
      nightHours: fields[12] as double,
      xcHours: fields[13] as double,
      remarks: fields[14] as String?,
      tags: (fields[15] as List).cast<String>(),
      status: fields[16] as String,
      createdAt: fields[17] as DateTime?,
      updatedAt: fields[18] as DateTime?,
      isDeleted: fields[19] as bool? ?? false,
      dualGivenHours: (fields[20] as double?) ?? 0,
      instrumentHours: (fields[21] as double?) ?? 0,
      soloHours: (fields[22] as double?) ?? 0,
      sicHours: (fields[23] as double?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, LogbookEntry obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.depIcao)
      ..writeByte(4)
      ..write(obj.arrIcao)
      ..writeByte(5)
      ..write(obj.aircraftReg)
      ..writeByte(6)
      ..write(obj.flightType)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime)
      ..writeByte(9)
      ..write(obj.totalHours)
      ..writeByte(10)
      ..write(obj.picHours)
      ..writeByte(11)
      ..write(obj.dualHours)
      ..writeByte(12)
      ..write(obj.nightHours)
      ..writeByte(13)
      ..write(obj.xcHours)
      ..writeByte(14)
      ..write(obj.remarks)
      ..writeByte(15)
      ..write(obj.tags)
      ..writeByte(16)
      ..write(obj.status)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.isDeleted)
      ..writeByte(20)
      ..write(obj.dualGivenHours)
      ..writeByte(21)
      ..write(obj.instrumentHours)
      ..writeByte(22)
      ..write(obj.soloHours)
      ..writeByte(23)
      ..write(obj.sicHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogbookEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
