import 'attendance_record.dart';

class AttendanceLesson {
  const AttendanceLesson({required this.date, required this.records});

  final DateTime date;
  final List<AttendanceRecord> records;
}
