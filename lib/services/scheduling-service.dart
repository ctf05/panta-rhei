import '../models/calendar_models.dart';
import '../models/person_model.dart';

class SchedulingService {
  List<EventInstance> calculateSchedule(
    List<CalendarEvent> events,
    List<Person> people,
    DateTime startDate,
    DateTime endDate,
  ) {
    final instances = <EventInstance>[];
    final personHours = Map<String, int>.fromIterable(
      people,
      key: (p) => (p as Person).id,
      value: (_) => 0,
    );

    // Sort events by priority
    final sortedEvents = _sortEventsByPriority(events);

    // Process each event
    for (var event in sortedEvents) {
      if (event.isRecurrent) {
        _scheduleRecurringEvent(
          event,
          startDate,
          endDate,
          instances,
          people,
          personHours,
        );
      } else {
        _scheduleOneTimeEvent(
          event,
          startDate,
          endDate,
          instances,
          people,
          personHours,
        );
      }
    }

    return instances;
  }

  List<CalendarEvent> _sortEventsByPriority(List<CalendarEvent> events) {
    return List<CalendarEvent>.from(events)..sort((a, b) {
      // Priority order: meetings > events > outreach
      final typeOrder = {
        EventType.meeting: 0,
        EventType.event: 1,
        EventType.outreach: 2,
      };
      
      final typeComparison = typeOrder[a.type]!.compareTo(typeOrder[b.type]!);
      if (typeComparison != 0) return typeComparison;

      // If same type, prioritize events with more constraints
      final aConstraints = _calculateConstraints(a);
      final bConstraints = _calculateConstraints(b);
      return bConstraints.compareTo(aConstraints);
    });
  }

  int _calculateConstraints(CalendarEvent event) {
    var score = 0;
    
    // More attendees = more constraints
    score += event.attendees.length * 2;
    
    // Recurring events have more constraints
    if (event.isRecurrent) {
      score += 5;
    }

    // Outreach events with tight min/max requirements
    if (event.isOutreach && event.minPeople != null && event.maxPeople != null) {
      if (event.maxPeople! - event.minPeople! <= 2) {
        score += 3;
      }
    }

    // Limited time slot options
    score += (20 - event.possibleTimeSlots.length).clamp(0, 10);

    return score;
  }

  void _scheduleRecurringEvent(
    CalendarEvent event,
    DateTime startDate,
    DateTime endDate,
    List<EventInstance> instances,
    List<Person> people,
    Map<String, int> personHours,
  ) {
    final frequency = Duration(days: event.frequencyDays!);
    var currentDate = startDate;
    var count = 0;

    while (currentDate.isBefore(endDate) && count < event.frequencyTimes!) {
      final instance = _findBestTimeSlot(
        event,
        currentDate,
        instances,
        people,
        personHours,
      );

      if (instance != null) {
        instances.add(instance);
        count++;
        
        // Update person hours for outreach events
        if (event.type == EventType.outreach) {
          for (var personId in instance.assignedPeople) {
            personHours[personId] = 
                personHours[personId]! + (instance.endHour - instance.startHour);
          }
        }
      }

      currentDate = currentDate.add(frequency);
    }
  }

  void _scheduleOneTimeEvent(
    CalendarEvent event,
    DateTime startDate,
    DateTime endDate,
    List<EventInstance> instances,
    List<Person> people,
    Map<String, int> personHours,
  ) {
    for (var slot in event.possibleTimeSlots) {
      if (slot.date.isBefore(startDate) || slot.date.isAfter(endDate)) continue;

      final instance = _findBestTimeSlot(
        event,
        slot.date,
        instances,
        people,
        personHours,
      );

      if (instance != null) {
        instances.add(instance);
        
        // Update person hours for outreach events
        if (event.type == EventType.outreach) {
          for (var personId in instance.assignedPeople) {
            personHours[personId] = 
                personHours[personId]! + (instance.endHour - instance.startHour);
          }
        }
        break;
      }
    }
  }

  EventInstance? _findBestTimeSlot(
    CalendarEvent event,
    DateTime date,
    List<EventInstance> existingInstances,
    List<Person> people,
    Map<String, int> personHours,
  ) {
    // Get all possible slots for this date
    final possibleSlots = event.possibleTimeSlots
        .where((slot) => 
            slot.date.year == date.year &&
            slot.date.month == date.month &&
            slot.date.day == date.day)
        .toList();

    if (possibleSlots.isEmpty) return null;

    // Score each possible time slot
    final scoredSlots = <TimeSlot, double>{};
    for (var slot in possibleSlots) {
      // Check for conflicts
      final hasConflict = _hasTimeConflict(
        date,
        slot.startHour,
        slot.endHour,
        existingInstances,
      );

      if (hasConflict) continue;

      // Find available people
      final availablePeople = _findAvailablePeople(
        event,
        date,
        slot.startHour,
        slot.endHour,
        existingInstances,
        people,
      );

      // Check if we have enough people
      if (event.isOutreach) {
        if (availablePeople.length < (event.minPeople ?? 1)) continue;
        if (availablePeople.length > (event.maxPeople ?? availablePeople.length)) continue;
      } else if (availablePeople.isEmpty) {
        continue;
      }

      // Score the slot
      final score = _scoreTimeSlot(
        slot,
        availablePeople,
        event,
        personHours,
      );

      if (score > 0) {
        scoredSlots[slot] = score;
      }
    }

    if (scoredSlots.isEmpty) return null;

    // Get the slot with the highest score
    final bestSlot = scoredSlots.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Get the best people for this slot
    final selectedPeople = _selectBestPeople(
      event,
      bestSlot,
      _findAvailablePeople(
        event,
        date,
        bestSlot.startHour,
        bestSlot.endHour,
        existingInstances,
        people,
      ),
      personHours,
    );

    return EventInstance(
      eventId: event.id,
      date: date,
      startHour: bestSlot.startHour,
      endHour: bestSlot.endHour,
      assignedPeople: selectedPeople,
    );
  }

  bool _hasTimeConflict(
    DateTime date,
    int startHour,
    int endHour,
    List<EventInstance> instances,
  ) {
    return instances.any((instance) =>
        instance.date.year == date.year &&
        instance.date.month == date.month &&
        instance.date.day == date.day &&
        ((instance.startHour >= startHour && instance.startHour < endHour) ||
         (instance.endHour > startHour && instance.endHour <= endHour)));
  }

  List<String> _findAvailablePeople(
    CalendarEvent event,
    DateTime date,
    int startHour,
    int endHour,
    List<EventInstance> instances,
    List<Person> people,
  ) {
    return people
        .where((person) =>
            event.attendees.contains(person.id) &&
            person.isAvailable(date, startHour, endHour) &&
            !_hasPersonConflict(
              person.id,
              date,
              startHour,
              endHour,
              instances,
            ))
        .map((person) => person.id)
        .toList();
  }

  bool _hasPersonConflict(
    String personId,
    DateTime date,
    int startHour,
    int endHour,
    List<EventInstance> instances,
  ) {
    return instances.any((instance) =>
        instance.date.year == date.year &&
        instance.date.month == date.month &&
        instance.date.day == date.day &&
        instance.assignedPeople.contains(personId) &&
        ((instance.startHour >= startHour && instance.startHour < endHour) ||
         (instance.endHour > startHour && instance.endHour <= endHour)));
  }

  double _scoreTimeSlot(
    TimeSlot slot,
    List<String> availablePeople,
    CalendarEvent event,
    Map<String, int> personHours,
  ) {
    var score = 100.0;

    // Prefer slots with more available people
    score += (availablePeople.length / event.attendees.length) * 50;

    // Prefer earlier slots in the day
    score -= (slot.startHour - 6) * 2;

    // For outreach events, consider workload balance
    if (event.type == EventType.outreach) {
      final avgHours = personHours.values.reduce((a, b) => a + b) / 
                      personHours.length;
      
      // Calculate standard deviation of hours
      final variance = personHours.values
          .map((hours) => (hours - avgHours) * (hours - avgHours))
          .reduce((a, b) => a + b) / personHours.length;
      final stdDev = variance.abs();

      // Penalize high standard deviation (unbalanced workload)
      score -= stdDev * 5;
    }

    return score;
  }

  List<String> _selectBestPeople(
    CalendarEvent event,
    TimeSlot slot,
    List<String> availablePeople,
    Map<String, int> personHours,
  ) {
    if (event.type == EventType.outreach) {
      // Sort by hours worked (ascending)
      availablePeople.sort((a, b) => 
          personHours[a]!.compareTo(personHours[b]!));

      // Select minimum required people with lowest hours
      return availablePeople
          .take(event.minPeople ?? availablePeople.length)
          .toList();
    } else {
      // For non-outreach events, include all available people
      return availablePeople;
    }
  }
}