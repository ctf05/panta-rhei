import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_models.dart';
import '../models/person_model.dart';
import '../state/app_state.dart';
import '../widgets/calendar_widget.dart';

class MainCalendarTab extends StatefulWidget {
  const MainCalendarTab({super.key});

  @override
  State<MainCalendarTab> createState() => _MainCalendarTabState();
}

class _MainCalendarTabState extends State<MainCalendarTab> {
  bool _isCalculating = false;

  Future<void> _showEventDetails(BuildContext context, EventInstance instance) async {
    final appState = context.read<AppState>();
    final event = appState.getEvent(instance.eventId);
    if (event == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(instance.customName ?? event.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${event.type.toString().split('.').last}'),
              const SizedBox(height: 8),
              Text('Time: ${instance.startHour}:00 - ${instance.endHour}:00'),
              const SizedBox(height: 8),
              Text('Description: ${instance.customDescription ?? event.description}'),
              const SizedBox(height: 16),
              const Text('Assigned People:'),
              ...instance.assignedPeople.map((personId) {
                final person = appState.getPerson(personId);
                if (person == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• ${person.name}'),
                );
              }),
            ],
          ),
        ),
        actions: [
          if (!DateTime.now().isAfter(instance.date)) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditInstanceForm(context, instance);
              },
              child: const Text('Edit'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditInstanceForm(BuildContext context, EventInstance instance) async {
    final appState = context.read<AppState>();
    final event = appState.getEvent(instance.eventId);
    if (event == null) return;

    final nameController = TextEditingController(text: instance.customName);
    final descController = TextEditingController(text: instance.customDescription);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Instance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Custom Name',
                  hintText: 'Leave blank to use event name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Custom Description',
                  hintText: 'Leave blank to use event description',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final updatedInstance = instance.copyWith(
                customName: nameController.text.isEmpty ? null : nameController.text,
                customDescription: descController.text.isEmpty ? null : descController.text,
              );
              await appState.updateEventInstance(updatedInstance);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEventMoved(
      BuildContext context,
      EventInstance instance,
      DateTime newDate,
      int newHour,
      ) async {
    // Check if the new date is in the past
    if (newDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move events to past dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Event?'),
        content: Text(
          'Are you sure you want to move this event to ${newDate.month}/${newDate.day} at $newHour:00?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Move the event
    await context.read<AppState>().moveEventInstance(
      instance,
      newDate,
      newHour,
    );
  }

  Future<void> _autoCalculateCalendar(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Calculate Calendar?'),
        content: const Text(
          'This will recalculate all event instances for the current week. '
              'Any manual adjustments will be lost. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCalculating = true);

    try {
      await context.read<AppState>().autoCalculateCalendar();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar has been recalculated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating calendar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: WeekCalendar(
                    initialDate: appState.selectedWeek,
                    events: appState.currentInstances ?? [],
                    isEditable: true,
                    allowDragDrop: true,
                    onEventTapped: (instance) => _showEventDetails(context, instance),
                    onEventMoved: (instance, date, hour) =>
                        _handleEventMoved(context, instance, date, hour),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCalculating
                          ? null
                          : () => _autoCalculateCalendar(context),
                      child: _isCalculating
                          ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Calculating...'),
                        ],
                      )
                          : const Text('Auto Calculate Calendar'),
                    ),
                  ),
                ),
              ],
            ),
            if (_isCalculating)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }
}