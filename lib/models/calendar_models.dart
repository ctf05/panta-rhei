import 'package:uuid/uuid.dart';

enum EventType { event, meeting, outreach }

class TimeSlot {
  final DateTime date;
  final int startHour;
  final int endHour;

  TimeSlot({
    required this.date,
    required this.startHour,
    required this.endHour,
  });

  bool overlaps(TimeSlot other) {
    if (date != other.date) return false;
    return (startHour < other.endHour && endHour > other.startHour);
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'startHour': startHour,
      'endHour': endHour,
    };
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      date: DateTime.parse(json['date']),
      startHour: json['startHour'],
      endHour: json['endHour'],
    );
  }
}

class CalendarEvent {
  final String id;
  final String name;
  final String description;
  final EventType type;
  final bool isRecurrent;
  final int? frequencyTimes;
  final int? frequencyDays;
  final List<String> attendees;
  final List<TimeSlot> possibleTimeSlots;
  final int? minPeople;
  final int? maxPeople;
  
  CalendarEvent({
    String? id,
    required this.name,
    required this.description,
    required this.type,
    required this.isRecurrent,
    this.frequencyTimes,
    this.frequencyDays,
    required this.attendees,
    required this.possibleTimeSlots,
    this.minPeople,
    this.maxPeople,
  }) : id = id ?? const Uuid().v4();

  bool get isOutreach => type == EventType.outreach;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString(),
      'isRecurrent': isRecurrent,
      'frequencyTimes': frequencyTimes,
      'frequencyDays': frequencyDays,
      'attendees': attendees,
      'possibleTimeSlots': possibleTimeSlots.map((slot) => slot.toJson()).toList(),
      'minPeople': minPeople,
      'maxPeople': maxPeople,
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: EventType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      isRecurrent: json['isRecurrent'],
      frequencyTimes: json['frequencyTimes'],
      frequencyDays: json['frequencyDays'],
      attendees: List<String>.from(json['attendees']),
      possibleTimeSlots: (json['possibleTimeSlots'] as List)
          .map((slot) => TimeSlot.fromJson(slot))
          .toList(),
      minPeople: json['minPeople'],
      maxPeople: json['maxPeople'],
    );
  }

  CalendarEvent copyWith({
    String? name,
    String? description,
    EventType? type,
    bool? isRecurrent,
    int? frequencyTimes,
    int? frequencyDays,
    List<String>? attendees,
    List<TimeSlot>? possibleTimeSlots,
    int? minPeople,
    int? maxPeople,
  }) {
    return CalendarEvent(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      isRecurrent: isRecurrent ?? this.isRecurrent,
      frequencyTimes: frequencyTimes ?? this.frequencyTimes,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      attendees: attendees ?? this.attendees,
      possibleTimeSlots: possibleTimeSlots ?? this.possibleTimeSlots,
      minPeople: minPeople ?? this.minPeople,
      maxPeople: maxPeople ?? this.maxPeople,
    );
  }
}

class EventInstance {
  final String id;
  final String eventId;
  final DateTime date;
  final int startHour;
  final int endHour;
  final List<String> assignedPeople;
  final String? customName;
  final String? customDescription;

  EventInstance({
    String? id,
    required this.eventId,
    required this.date,
    required this.startHour,
    required this.endHour,
    required this.assignedPeople,
    this.customName,
    this.customDescription,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'date': date.toIso8601String(),
      'startHour': startHour,
      'endHour': endHour,
      'assignedPeople': assignedPeople,
      'customName': customName,
      'customDescription': customDescription,
    };
  }

  factory EventInstance.fromJson(Map<String, dynamic> json) {
    return EventInstance(
      id: json['id'],
      eventId: json['eventId'],
      date: DateTime.parse(json['date']),
      startHour: json['startHour'],
      endHour: json['endHour'],
      assignedPeople: List<String>.from(json['assignedPeople']),
      customName: json['customName'],
      customDescription: json['customDescription'],
    );
  }

  EventInstance copyWith({
    DateTime? date,
    int? startHour,
    int? endHour,
    List<String>? assignedPeople,
    String? customName,
    String? customDescription,
  }) {
    return EventInstance(
      id: id,
      eventId: eventId,
      date: date ?? this.date,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      assignedPeople: assignedPeople ?? this.assignedPeople,
      customName: customName ?? this.customName,
      customDescription: customDescription ?? this.customDescription,
    );
  }
}
