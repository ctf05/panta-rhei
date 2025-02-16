import 'package:flutter/foundation.dart';
import '../models/calendar_models.dart';
import '../models/person_model.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  DateTime _selectedWeek = DateTime.now();
  DateTime get selectedWeek => _selectedWeek;

  void setSelectedWeek(DateTime week) {
    _selectedWeek = week;
    notifyListeners();
  }

  List<EventInstance>? _currentInstances;
  List<EventInstance>? get currentInstances => _currentInstances;

  List<CalendarEvent>? _events;
  List<CalendarEvent>? get events => _events;

  List<Person>? _people;
  List<Person>? get people => _people;

  void init() {
    // Listen to events
    _firebaseService.streamEvents().listen((events) {
      _events = events;
      notifyListeners();
    });

    // Listen to people
    _firebaseService.streamPeople().listen((people) {
      _people = people;
      notifyListeners();
    });

    // Listen to current week's instances
    _updateInstancesSubscription();
  }

  void _updateInstancesSubscription() {
    final weekStart = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    _firebaseService
        .streamEventInstances(weekStart, weekEnd)
        .listen((instances) {
      _currentInstances = instances;
      notifyListeners();
    });
  }

  Future<void> createPerson(Person person) async {
    await _firebaseService.createPerson(person);
  }

  Future<void> autoCalculateCalendar() async {
    final weekStart = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    await _firebaseService.autoCalculateCalendar(weekStart, weekEnd);
  }

  Future<void> moveEventInstance(
      EventInstance instance,
      DateTime newDate,
      int newHour,
      ) async {
    final duration = instance.endHour - instance.startHour;
    final updatedInstance = instance.copyWith(
      date: newDate,
      startHour: newHour,
      endHour: newHour + duration,
    );
    await _firebaseService.updateEventInstance(updatedInstance);
  }

  Future<void> updatePerson(Person person) async {
    await _firebaseService.updatePerson(person);
  }

  Future<void> createEvent(CalendarEvent event) async {
    await _firebaseService.createEvent(event);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _firebaseService.updateEvent(event);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firebaseService.deleteEvent(eventId);
  }

  Future<void> updateEventInstance(EventInstance instance) async {
    await _firebaseService.updateEventInstance(instance);
  }

  bool isPersonBusy(String personId, DateTime date, int startHour, int endHour) {
    if (_currentInstances == null) return false;

    return _currentInstances!.any((instance) =>
    instance.date.year == date.year &&
        instance.date.month == date.month &&
        instance.date.day == date.day &&
        instance.assignedPeople.contains(personId) &&
        ((instance.startHour >= startHour && instance.startHour < endHour) ||
            (instance.endHour > startHour && instance.endHour <= endHour)));
  }

  CalendarEvent? getEvent(String eventId) {
    if (_events == null) return null;
    return _events!.firstWhere(
          (event) => event.id == eventId,
      orElse: () => null as CalendarEvent,
    );
  }

  Person? getPerson(String personId) {
    if (_people == null) return null;
    return _people!.firstWhere(
          (person) => person.id == personId,
      orElse: () => null as Person,
    );
  }
}