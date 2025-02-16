import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/calendar_models.dart';
import '../models/person_model.dart';
import '../state/app_state.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/time_grid.dart';

class PersonTab extends StatefulWidget {
  final String personId;

  const PersonTab({
    super.key,
    required this.personId,
  });

  @override
  State<PersonTab> createState() => _PersonTabState();
}

class _PersonTabState extends State<PersonTab> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = false;
  late DateTime selectedWeek;

  @override
  void initState() {
    super.initState();
    selectedWeek = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _previousWeek() {
    setState(() {
      selectedWeek = selectedWeek.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      selectedWeek = selectedWeek.add(const Duration(days: 7));
    });
  }

  void _toggleTimeSlot(
      Person person, DateTime date, int startHour, int endHour) {
    final appState = context.read<AppState>();

    // Check if the time slot already exists
    final existingSlot = person.availability.any((slot) =>
        slot.date.year == date.year &&
        slot.date.month == date.month &&
        slot.date.day == date.day &&
        slot.startHour == startHour &&
        slot.endHour == endHour);

    final newAvailability = List<TimeSlot>.from(person.availability);

    if (existingSlot) {
      // Remove the slot
      newAvailability.removeWhere((slot) =>
          slot.date.year == date.year &&
          slot.date.month == date.month &&
          slot.date.day == date.day &&
          slot.startHour == startHour &&
          slot.endHour == endHour);
    } else {
      // Add the slot
      newAvailability.add(TimeSlot(
        date: date,
        startHour: startHour,
        endHour: endHour,
      ));
    }

    final updatedPerson = person.copyWith(
      availability: newAvailability,
    );

    appState.updatePerson(updatedPerson);
  }

  void _onDaySelected(Person person, DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        int startHour = 6;
        int endHour = 24;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Availability'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Date: ${date.month}/${date.day}/${date.year}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                          ),
                          value: startHour,
                          items: List.generate(18, (index) => index + 6)
                              .map((hour) {
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('$hour:00'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              startHour = value;
                              if (endHour <= startHour) {
                                endHour = startHour + 1;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                          ),
                          value: endHour,
                          items: List.generate(18, (index) => index + 6)
                              .map((hour) {
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('$hour:00'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => endHour = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _toggleTimeSlot(person, date, startHour, endHour);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyWeeklySchedule(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Weekly Schedule'),
        content: const Text(
          'This will apply the current week\'s schedule to all future weeks. '
          'Any existing schedule will be overwritten. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Get the current week's schedule
      final weekStart =
          selectedWeek.subtract(Duration(days: selectedWeek.weekday - 1));

      final currentWeekSlots = person.availability
          .where((slot) =>
              slot.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              slot.date.isBefore(weekStart.add(const Duration(days: 7))))
          .toList();

      // Create slots for future weeks
      final newAvailability = List<TimeSlot>.from(person.availability);

      // Add slots for the next 52 weeks
      for (var i = 1; i < 52; i++) {
        final futureWeekStart = weekStart.add(Duration(days: 7 * i));

        for (var slot in currentWeekSlots) {
          final dayOffset = slot.date.difference(weekStart).inDays;
          final futureDate = futureWeekStart.add(Duration(days: dayOffset));

          newAvailability.add(TimeSlot(
            date: futureDate,
            startHour: slot.startHour,
            endHour: slot.endHour,
          ));
        }
      }

      final updatedPerson = person.copyWith(
        availability: newAvailability,
      );

      await context.read<AppState>().updatePerson(updatedPerson);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly schedule has been applied to all future weeks'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying weekly schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final person = appState.getPerson(widget.personId);

        if (person == null) {
          return const Center(child: Text('Person not found'));
        }

        if (!_isEditingName) {
          _nameController.text = person.name;
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          if (_isEditingName) ...[
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                ),
                                autofocus: true,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () async {
                                final updatedPerson = person.copyWith(
                                  name: _nameController.text,
                                );
                                await appState.updatePerson(updatedPerson);
                                setState(() => _isEditingName = false);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _isEditingName = false);
                                _nameController.text = person.name;
                              },
                            ),
                          ] else ...[
                            Expanded(
                              child: Text(
                                person.name,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  setState(() => _isEditingName = true),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Availability Schedule',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Apply to All Weeks'),
                                onPressed: () => _applyWeeklySchedule(person),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 600,
                          child: Column(
                            children: [
                              // Navigation bar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                color: Theme.of(context).colorScheme.primary,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left,
                                          color: Colors.white),
                                      onPressed: _previousWeek,
                                    ),
                                    Text(
                                      '${DateFormat('MMM d').format(selectedWeek)} - '
                                      '${DateFormat('MMM d').format(selectedWeek.add(const Duration(days: 6)))}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right,
                                          color: Colors.white),
                                      onPressed: _nextWeek,
                                    ),
                                  ],
                                ),
                              ),
                              // Calendar grid
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: ScrollController(),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Time column
                                      SizedBox(
                                        width: 80,
                                        child: Column(
                                          children: [
                                            // Header spacer
                                            Container(
                                              height: 60,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFF1a4966)),
                                                color: const Color(0xFFec4755),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'Time',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Hour labels
                                            ...List.generate(24 - 6, (index) {
                                              final hour = 6 + index;
                                              return Container(
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFF1a4966)),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${hour.toString().padLeft(2, '0')}:00',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1a4966),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                      // Day columns with TimeGrid
                                      Expanded(
                                        child: Row(
                                          children: List.generate(7, (index) {
                                            final day = selectedWeek
                                                .add(Duration(days: index));
                                            return Expanded(
                                              child: Column(
                                                children: [
                                                  // Day header
                                                  Container(
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFF1a4966)),
                                                      color: const Color(
                                                          0xFFec4755),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        DateFormat('E\nMMM d')
                                                            .format(day),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // TimeGrid for selection
                                                  TimeGrid(
                                                    date: day,
                                                    selectedSlots: person.availability,
                                                    onSlotSelected: (date, startHour, endHour) =>
                                                        _toggleTimeSlot(person, date, startHour, endHour),
                                                    onSlotRemoved: (date, startHour, endHour) =>
                                                        _toggleTimeSlot(person, date, startHour, endHour),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outreach Hours',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _OutreachStatCard(
                                  title: 'This Week',
                                  hours: person.outreachHours['weekly'] ?? 0,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _OutreachStatCard(
                                  title: 'This Month',
                                  hours: person.outreachHours['monthly'] ?? 0,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _OutreachStatCard(
                                  title: 'Total',
                                  hours: person.outreachHours['total'] ?? 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
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

class _OutreachStatCard extends StatelessWidget {
  final String title;
  final int hours;

  const _OutreachStatCard({
    required this.title,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$hours',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text('hours'),
        ],
      ),
    );
  }
}
