import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';
import '../widgets/time_grid.dart';

class EventForm extends StatefulWidget {
  final CalendarEvent? event;
  final List<String> availablePeople;
  final Function(CalendarEvent) onSave;

  const EventForm({
    super.key,
    this.event,
    required this.availablePeople,
    required this.onSave,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _frequencyTimesController;
  late TextEditingController _frequencyDaysController;
  late TextEditingController _minPeopleController;
  late TextEditingController _maxPeopleController;

  EventType _type = EventType.event;
  bool _isRecurrent = false;
  List<String> _selectedAttendees = [];
  List<TimeSlot> _possibleTimeSlots = [];
  bool _selectAll = false;
  late DateTime selectedWeek;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedWeek = DateTime.now();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.event?.description ?? '');
    _frequencyTimesController = TextEditingController(
        text: widget.event?.frequencyTimes?.toString() ?? '');
    _frequencyDaysController = TextEditingController(
        text: widget.event?.frequencyDays?.toString() ?? '');
    _minPeopleController =
        TextEditingController(text: widget.event?.minPeople?.toString() ?? '');
    _maxPeopleController =
        TextEditingController(text: widget.event?.maxPeople?.toString() ?? '');

    if (widget.event != null) {
      _type = widget.event!.type;
      _isRecurrent = widget.event!.isRecurrent;
      _selectedAttendees = List.from(widget.event!.attendees);
      _possibleTimeSlots = List.from(widget.event!.possibleTimeSlots);
      _selectAll = _selectedAttendees.length == widget.availablePeople.length;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _frequencyTimesController.dispose();
    _frequencyDaysController.dispose();
    _minPeopleController.dispose();
    _maxPeopleController.dispose();
    _scrollController.dispose();
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

  void _toggleTimeSlot(DateTime date, int startHour, int endHour) {
    setState(() {
      // Check if slot exists
      final existingSlot = _possibleTimeSlots.any((slot) =>
          slot.date.year == date.year &&
          slot.date.month == date.month &&
          slot.date.day == date.day &&
          slot.startHour == startHour &&
          slot.endHour == endHour);

      if (existingSlot) {
        // Remove slot
        _possibleTimeSlots.removeWhere((slot) =>
            slot.date.year == date.year &&
            slot.date.month == date.month &&
            slot.date.day == date.day &&
            slot.startHour == startHour &&
            slot.endHour == endHour);
      } else {
        // Add slot
        _possibleTimeSlots.add(TimeSlot(
          date: date,
          startHour: startHour,
          endHour: endHour,
        ));
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    if (value == null) return;
    setState(() {
      _selectAll = value;
      _selectedAttendees = value ? List.from(widget.availablePeople) : [];
    });
  }

  void _toggleAttendee(String personId, bool? value) {
    if (value == null) return;
    setState(() {
      if (value) {
        _selectedAttendees.add(personId);
      } else {
        _selectedAttendees.remove(personId);
      }
      _selectAll = _selectedAttendees.length == widget.availablePeople.length;
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final event = CalendarEvent(
      id: widget.event?.id,
      name: _nameController.text,
      description: _descriptionController.text,
      type: _type,
      isRecurrent: _isRecurrent,
      frequencyTimes:
          _isRecurrent ? int.tryParse(_frequencyTimesController.text) : null,
      frequencyDays:
          _isRecurrent ? int.tryParse(_frequencyDaysController.text) : null,
      attendees: _selectedAttendees,
      possibleTimeSlots: _possibleTimeSlots,
      minPeople: _type == EventType.outreach
          ? int.tryParse(_minPeopleController.text)
          : null,
      maxPeople: _type == EventType.outreach
          ? int.tryParse(_maxPeopleController.text)
          : null,
    );

    widget.onSave(event);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                hintText: 'Enter event name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an event name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter event description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EventType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Event Type',
              ),
              items: EventType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recurring Event'),
              value: _isRecurrent,
              onChanged: (value) => setState(() => _isRecurrent = value),
            ),
            if (_isRecurrent) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _frequencyTimesController,
                      decoration: const InputDecoration(
                        labelText: 'Times',
                        hintText: 'How many times',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Must be a number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _frequencyDaysController,
                      decoration: const InputDecoration(
                        labelText: 'Days',
                        hintText: 'Per how many days',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Must be a number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (_type == EventType.outreach) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minPeopleController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum People',
                        hintText: 'Min required',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Must be a number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxPeopleController,
                      decoration: const InputDecoration(
                        labelText: 'Maximum People',
                        hintText: 'Max allowed',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Must be a number';
                        }
                        final min = int.tryParse(_minPeopleController.text);
                        final max = int.tryParse(value);
                        if (min != null && max != null && max < min) {
                          return 'Must be ≥ min';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Possible Time Slots',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Click and drag to select or remove time slots',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(
              height: 600,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.primary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Column(
                              children: [
                                Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFF1a4966)),
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
                                ...List.generate(24 - 6, (index) {
                                  final hour = 6 + index;
                                  return Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFF1a4966)),
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
                          Expanded(
                            child: Row(
                              children: List.generate(7, (index) {
                                final day =
                                    selectedWeek.add(Duration(days: index));
                                return Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: const Color(0xFF1a4966)),
                                          color: const Color(0xFFec4755),
                                        ),
                                        child: Center(
                                          child: Text(
                                            DateFormat('E\nMMM d').format(day),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      TimeGrid(
                                        date: day,
                                        selectedSlots: _possibleTimeSlots,
                                        onSlotSelected: _toggleTimeSlot,
                                        onSlotRemoved: _toggleTimeSlot,
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
            const SizedBox(height: 24),
            Text(
              'Attendees',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            CheckboxListTile(
              title: const Text('Select All'),
              value: _selectAll,
              onChanged: _toggleSelectAll,
            ),
            const Divider(),
            ...widget.availablePeople.map((person) {
              return CheckboxListTile(
                title: Text(person),
                value: _selectedAttendees.contains(person),
                onChanged: (value) => _toggleAttendee(person, value),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                child: const Text('Save Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
