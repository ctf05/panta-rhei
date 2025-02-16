import 'package:uuid/uuid.dart';
import 'calendar_models.dart';

class Person {
  final String id;
  final String name;
  final List<TimeSlot> availability;
  final Map<String, int> outreachHours;

  Person({
    String? id,
    required this.name,
    required this.availability,
    Map<String, int>? outreachHours,
  }) : id = id ?? const Uuid().v4(),
       outreachHours = outreachHours ?? {
         'weekly': 0,
         'monthly': 0,
         'total': 0,
       };

  bool isAvailable(DateTime date, int startHour, int endHour) {
    return availability.any((slot) =>
        slot.date.year == date.year &&
        slot.date.month == date.month &&
        slot.date.day == date.day &&
        slot.startHour <= startHour &&
        slot.endHour >= endHour);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'availability': availability.map((slot) => slot.toJson()).toList(),
      'outreachHours': outreachHours,
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      availability: (json['availability'] as List)
          .map((slot) => TimeSlot.fromJson(slot))
          .toList(),
      outreachHours: Map<String, int>.from(json['outreachHours']),
    );
  }

  Person copyWith({
    String? name,
    List<TimeSlot>? availability,
    Map<String, int>? outreachHours,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      availability: availability ?? this.availability,
      outreachHours: outreachHours ?? this.outreachHours,
    );
  }

  void updateOutreachHours(int hours) {
    outreachHours['total'] = (outreachHours['total'] ?? 0) + hours;
    outreachHours['weekly'] = (outreachHours['weekly'] ?? 0) + hours;
    outreachHours['monthly'] = (outreachHours['monthly'] ?? 0) + hours;
  }

  void resetWeeklyHours() {
    outreachHours['weekly'] = 0;
  }

  void resetMonthlyHours() {
    outreachHours['monthly'] = 0;
  }
}