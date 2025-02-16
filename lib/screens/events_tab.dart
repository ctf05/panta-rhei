import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_models.dart';
import '../models/person_model.dart';
import '../state/app_state.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_form.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  CalendarEvent? _selectedEvent;

  void _showCreateEventDialog(BuildContext context) {
    final appState = context.read<AppState>();
    final people = appState.people;
    if (people == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Event'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: EventForm(
            availablePeople: people.map((p) => p.id).toList(),
            onSave: (event) async {
              await appState.createEvent(event);
              if (!mounted) return;
              Navigator.of(context).pop();
              setState(() => _selectedEvent = event);
            },
          ),
        ),
      ),
    );
  }

  void _showConfirmDelete(BuildContext context) {
    if (_selectedEvent == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${_selectedEvent!.name}"? '
              'This will also delete all instances of this event.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              await context.read<AppState>().deleteEvent(_selectedEvent!.id);
              if (!mounted) return;
              Navigator.of(context).pop();
              setState(() => _selectedEvent = null);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<CalendarEvent> events) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isSelected = _selectedEvent?.id == event.id;

        return ListTile(
          title: Text(event.name),
          subtitle: Text(
            '${event.type.toString().split('.').last} • '
                '${event.isRecurrent ? "Recurring" : "One-time"}',
          ),
          leading: Icon(
            {
              EventType.event: Icons.event,
              EventType.meeting: Icons.groups,
              EventType.outreach: Icons.volunteer_activism,
            }[event.type],
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          selected: isSelected,
          onTap: () => setState(() => _selectedEvent = event),
        );
      },
    );
  }

  Widget _buildEventDetails(BuildContext context, CalendarEvent event, List<Person> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primary,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Event'),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: EventForm(
                          event: event,
                          availablePeople: people.map((p) => p.id).toList(),
                          onSave: (updatedEvent) async {
                            await context.read<AppState>().updateEvent(updatedEvent);
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            setState(() => _selectedEvent = updatedEvent);
                          },
                        ),
                      ),
                    ),
                  );
                },
                tooltip: 'Edit Event',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: () => _showConfirmDelete(context),
                tooltip: 'Delete Event',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(event.description),
              const SizedBox(height: 16),
              Text(
                'Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('Type: ${event.type.toString().split('.').last}'),
              if (event.isRecurrent)
                Text(
                  'Recurrence: ${event.frequencyTimes} times per '
                      '${event.frequencyDays} days',
                ),
              if (event.isOutreach)
                Text(
                  'People Required: ${event.minPeople} - '
                      '${event.maxPeople}',
                ),
              const SizedBox(height: 16),
              Text(
                'Attendees',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: event.attendees.map((personId) {
                  final person = people.firstWhere(
                        (p) => p.id == personId,
                    orElse: () => Person(name: 'Unknown', availability: []),
                  );
                  return Chip(
                    label: Text(person.name),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Possible Time Slots',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Consumer<AppState>(
            builder: (context, appState, _) {
              final instances = appState.currentInstances
                  ?.where((instance) => instance.eventId == event.id)
                  .toList() ?? [];

              return WeekCalendar(
                initialDate: appState.selectedWeek,
                events: instances,
                isEditable: true,
                allowDragDrop: false,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final events = appState.events;
        final people = appState.people;

        if (events == null || people == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Row(
          children: [
            // Events List
            SizedBox(
              width: 300,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primary,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Events',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => _showCreateEventDialog(context),
                            tooltip: 'Create New Event',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildEventsList(events),
                    ),
                  ],
                ),
              ),
            ),
            // Event Details and Calendar
            Expanded(
              child: _selectedEvent == null
                  ? const Center(
                child: Text('Select an event to view its details'),
              )
                  : Card(
                margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: _buildEventDetails(context, _selectedEvent!, people),
              ),
            ),
          ],
        );
      },
    );
  }
}