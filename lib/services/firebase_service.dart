import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_models.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Events Collection Reference
  CollectionReference get _eventsRef => _firestore.collection('events');

  // Event Instances Collection Reference
  CollectionReference get _instancesRef => _firestore.collection('event_instances');

  // People Collection Reference
  CollectionReference get _peopleRef => _firestore.collection('people');

  // Event Operations
  Stream<List<CalendarEvent>> streamEvents() {
    return _eventsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CalendarEvent.fromJson(data);
      }).toList();
    });
  }

  Future<void> createEvent(CalendarEvent event) async {
    await _eventsRef.doc(event.id).set(event.toJson());
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _eventsRef.doc(event.id).update(event.toJson());
  }

  Future<void> deleteEvent(String eventId) async {
    // Delete all instances of this event first
    final instances = await _instancesRef
        .where('eventId', isEqualTo: eventId)
        .get();

    final batch = _firestore.batch();
    for (var doc in instances.docs) {
      batch.delete(doc.reference);
    }

    // Delete the event
    batch.delete(_eventsRef.doc(eventId));

    await batch.commit();
  }

  // Event Instance Operations
  Stream<List<EventInstance>> streamEventInstances(DateTime startDate, DateTime endDate) {
    return _instancesRef
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return EventInstance.fromJson(data);
      }).toList();
    });
  }

  Future<void> createEventInstance(EventInstance instance) async {
    await _instancesRef.doc(instance.id).set(instance.toJson());
  }

  Future<void> updateEventInstance(EventInstance instance) async {
    await _instancesRef.doc(instance.id).update(instance.toJson());
  }

  Future<void> deleteEventInstance(String instanceId) async {
    await _instancesRef.doc(instanceId).delete();
  }

  // Person Operations
  Stream<List<Person>> streamPeople() {
    return _peopleRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Person.fromJson(data);
      }).toList();
    });
  }

  Future<void> createPerson(Person person) async {
    await _peopleRef.doc(person.id).set(person.toJson());
  }

  Future<void> updatePerson(Person person) async {
    await _peopleRef.doc(person.id).update(person.toJson());
  }

  Future<void> deletePerson(String personId) async {
    // Remove person from all event instances first
    final instances = await _instancesRef
        .where('assignedPeople', arrayContains: personId)
        .get();

    final batch = _firestore.batch();
    for (var doc in instances.docs) {
      final instance = EventInstance.fromJson(doc.data() as Map<String, dynamic>);
      final updatedPeople = instance.assignedPeople.where((id) => id != personId).toList();
      batch.update(doc.reference, {'assignedPeople': updatedPeople});
    }

    // Remove person from all events
    final events = await _eventsRef
        .where('attendees', arrayContains: personId)
        .get();

    for (var doc in events.docs) {
      final event = CalendarEvent.fromJson(doc.data() as Map<String, dynamic>);
      final updatedAttendees = event.attendees.where((id) => id != personId).toList();
      batch.update(doc.reference, {'attendees': updatedAttendees});
    }

    // Delete the person
    batch.delete(_peopleRef.doc(personId));

    await batch.commit();
  }

  // Calendar Operations
  Future<void> autoCalculateCalendar(DateTime startDate, DateTime endDate) async {
    // Get all events and people
    final eventsSnapshot = await _eventsRef.get();
    final peopleSnapshot = await _peopleRef.get();

    final events = eventsSnapshot.docs
        .map((doc) => CalendarEvent.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    final people = peopleSnapshot.docs
        .map((doc) => Person.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Clear existing instances in the date range
    final existingInstances = await _instancesRef
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .get();

    final batch = _firestore.batch();
    for (var doc in existingInstances.docs) {
      batch.delete(doc.reference);
    }

    // Calculate new schedule
    final newInstances = _calculateSchedule(events, people, startDate, endDate);

    // Create new instances
    for (var instance in newInstances) {
      batch.set(_instancesRef.doc(instance.id), instance.toJson());
    }

    await batch.commit();
  }

  final SchedulingService _schedulingService = SchedulingService();

  List<EventInstance> _calculateSchedule(
      List<CalendarEvent> events,
      List<Person> people,
      DateTime startDate,
      DateTime endDate,
      ) {
    return _schedulingService.calculateSchedule(
      events,
      people,
      startDate,
      endDate,
    );
  }

  EventInstance? _scheduleEvent(
      CalendarEvent event,
      DateTime date,
      List<EventInstance> existingInstances,
      List<Person> people,
      Map<String, int> personHours,
      ) {
    // Find available time slots
    final availableSlots = event.possibleTimeSlots
        .where((slot) => slot.date.year == date.year &&
        slot.date.month == date.month &&
        slot.date.day == date.day)
        .toList();

    if (availableSlots.isEmpty) return null;

    for (var slot in availableSlots) {
      // Check for conflicts
      final hasConflict = existingInstances.any((instance) =>
      instance.date == date &&
          ((instance.startHour >= slot.startHour && instance.startHour < slot.endHour) ||
              (instance.endHour > slot.startHour && instance.endHour <= slot.endHour)));

      if (hasConflict) continue;

      // Find available people
      final availablePeople = _findAvailablePeople(
        event,
        date,
        slot.startHour,
        slot.endHour,
        existingInstances,
        people,
        personHours,
      );

      if (availablePeople.isEmpty) continue;

      // Create instance
      return EventInstance(
        eventId: event.id,
        date: date,
        startHour: slot.startHour,
        endHour: slot.endHour,
        assignedPeople: availablePeople,
      );
    }

    return null;
  }

  List<String> _findAvailablePeople(
      CalendarEvent event,
      DateTime date,
      int startHour,
      int endHour,
      List<EventInstance> existingInstances,
      List<Person> people,
      Map<String, int> personHours,
      ) {
    // Filter people by availability and conflicts
    final availablePeople = people
        .where((person) =>
    event.attendees.contains(person.id) &&
        person.isAvailable(date, startHour, endHour) &&
        !_hasConflict(person.id, date, startHour, endHour, existingInstances))
        .toList();

    if (availablePeople.isEmpty) return [];

    // For outreach events, balance workload
    if (event.type == EventType.outreach) {
      availablePeople.sort((a, b) =>
          personHours[a.id]!.compareTo(personHours[b.id]!));

      final count = event.minPeople != null
          ? event.minPeople!
          : availablePeople.length;

      final selected = availablePeople.take(count).map((p) => p.id).toList();

      // Update hours
      for (var personId in selected) {
        personHours[personId] = personHours[personId]! + (endHour - startHour);
      }

      return selected;
    }

    // For other events, include all available people
    return availablePeople.map((p) => p.id).toList();
  }

  bool _hasConflict(
      String personId,
      DateTime date,
      int startHour,
      int endHour,
      List<EventInstance> instances,
      ) {
    return instances.any((instance) =>
    instance.date == date &&
        instance.assignedPeople.contains(personId) &&
        ((instance.startHour >= startHour && instance.startHour < endHour) ||
            (instance.endHour > startHour && instance.endHour <= endHour)));
  }
}