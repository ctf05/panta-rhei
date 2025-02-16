import 'package:flutter/material.dart';
import '../models/calendar_models.dart';

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
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _frequencyTimesController = TextEditingController(text: widget.event?.frequencyTimes?.toString() ?? '');
    _frequencyDaysController = TextEditingController(text: widget.event?.frequencyDays?.toString() ?? '');
    _minPeopleController = TextEditingController(text: widget.event?.minPeople?.toString() ?? '');
    _maxPeopleController = TextEditingController(text: widget.event?.maxPeople?.toString() ?? '');
    
    if (widget.event != null) {
      _type = widget.event!.type;
      _isRecurrent = widget.event!.isRecurrent;
      _selectedAttendees = List.from(widget.event!.attendees);
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
    super.dispose();
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
      frequencyTimes: _isRecurrent ? int.tryParse(_frequencyTimesController.text) : null,
      frequencyDays: _isRecurrent ? int.tryParse(_frequencyDaysController.text) : null,
      attendees: _selectedAttendees,
      possibleTimeSlots: widget.event?.possibleTimeSlots ?? [],
      minPeople: _type == EventType.outreach ? int.tryParse(_minPeopleController.text) : null,
      maxPeople: _type == EventType.outreach ? int.tryParse(_maxPeopleController.text) : null,
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
