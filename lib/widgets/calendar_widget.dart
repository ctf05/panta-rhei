import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';

class WeekCalendar extends StatefulWidget {
  final DateTime initialDate;
  final List<EventInstance> events;
  final bool isEditable;
  final bool allowDragDrop;
  final Function(DateTime)? onDaySelected;
  final Function(int)? onHourSelected;
  final Function(EventInstance, DateTime, int)? onEventMoved;
  final Function(EventInstance)? onEventTapped;

  const WeekCalendar({
    super.key,
    required this.initialDate,
    required this.events,
    this.isEditable = true,
    this.allowDragDrop = true,
    this.onDaySelected,
    this.onHourSelected,
    this.onEventMoved,
    this.onEventTapped,
  });

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  late DateTime _selectedWeekStart;
  static const startHour = 6;
  static const endHour = 24;
  final ScrollController _scrollController = ScrollController();
  final double _cellHeight = 60.0;
  final double _headerHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(widget.initialDate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
  }

  List<DateTime> _getWeekDays() {
    return List.generate(
      7,
          (index) => _selectedWeekStart.add(Duration(days: index)),
    );
  }

  Widget _buildEventCard(EventInstance event) {
    final duration = event.endHour - event.startHour;
    final height = duration * _cellHeight;

    Color eventColor;
    switch (event.eventId.split('_')[0]) {
      case 'event':
        eventColor = const Color(0xFFec4755);
        break;
      case 'meeting':
        eventColor = const Color(0xFFa12c34);
        break;
      case 'outreach':
        eventColor = const Color(0xFFffba75);
        break;
      default:
        eventColor = const Color(0xFFec4755);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: eventColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.customName ?? 'Event',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (height > 40)
            Text(
              '${event.startHour.toString().padLeft(2, '0')}:00 - '
                  '${event.endHour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          if (height > 32 && event.assignedPeople.isNotEmpty)
            Text(
              '${event.assignedPeople.length} attendees',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  int _calculateHourFromPosition(double dy) {
    final hourIndex = ((dy - _headerHeight) / _cellHeight).floor();
    return (hourIndex + startHour).clamp(startHour, endHour - 1);
  }

  Future<void> _handleEventMoved(
      BuildContext context,
      EventInstance instance,
      DateTime newDate,
      double dropY,
      ) async {
    // Get the target hour from the drop position
    final newHour = _calculateHourFromPosition(dropY);

    // Check if the new date is in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(newDate.year, newDate.month, newDate.day);

    if (eventDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move events to past dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate event duration
    final duration = instance.endHour - instance.startHour;
    final endHour = newHour + duration;

    // Validate end hour doesn't exceed day boundary
    if (endHour > endHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event would extend past end of day'),
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
          'Are you sure you want to move this event to ${newDate.month}/${newDate.day} at '
              '${newHour.toString().padLeft(2, '0')}:00?',
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
    widget.onEventMoved?.call(instance, newDate, newHour);
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousWeek,
              ),
              Text(
                '${DateFormat('MMM d').format(_selectedWeekStart)} - '
                    '${DateFormat('MMM d').format(_selectedWeekStart.add(const Duration(days: 6)))}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _nextWeek,
              ),
            ],
          ),
        ),
        // Calendar grid
        Expanded(
          child: Column(
            children: [
              // Headers row
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    // Time header
                    SizedBox(
                      width: 80,
                      child: Container(
                        height: _headerHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1a4966)),
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
                    ),
                    // Day headers
                    ...weekDays.map((day) => Expanded(
                      child: Container(
                        height: _headerHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1a4966)),
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
                    )),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      SizedBox(
                        width: 80,
                        child: Column(
                          children: List.generate(endHour - startHour, (index) {
                            final hour = startHour + index;
                            return Container(
                              height: _cellHeight,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF1a4966)),
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
                        ),
                      ),
                      // Day columns with events
                      ...weekDays.map((day) {
                        final dayEvents = widget.events.where((event) =>
                        event.date.year == day.year &&
                            event.date.month == day.month &&
                            event.date.day == day.day
                        ).toList();

                        final isPastDay = day.isBefore(today);

                        return Expanded(
                          child: DragTarget<EventInstance>(
                            onWillAccept: (data) => widget.isEditable && widget.allowDragDrop,
                            onAcceptWithDetails: (details) {
                              final eventInstance = details.data;
                              _handleEventMoved(
                                context,
                                eventInstance,
                                day,
                                details.offset.dy,
                              );
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Stack(
                                children: [
                                  // Hour grid
                                  Column(
                                    children: List.generate(endHour - startHour, (index) {
                                      final hour = startHour + index;
                                      return GestureDetector(
                                        onTap: () {
                                          if (widget.isEditable && !isPastDay) {
                                            widget.onDaySelected?.call(day);
                                            widget.onHourSelected?.call(hour);
                                          }
                                        },
                                        child: Container(
                                          height: _cellHeight,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: const Color(0xFF1a4966)),
                                            color: isPastDay && !widget.isEditable
                                                ? Colors.grey.withOpacity(0.1)
                                                : null,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  // Events
                                  ...dayEvents.map((event) {
                                    final top = (event.startHour - startHour) * _cellHeight;
                                    final height = (event.endHour - event.startHour) * _cellHeight;

                                    final eventWidget = GestureDetector(
                                      onTap: () => widget.onEventTapped?.call(event),
                                      child: _buildEventCard(event),
                                    );

                                    // For past events or when editing is disabled, return non-draggable event
                                    if (isPastDay || !widget.isEditable || !widget.allowDragDrop) {
                                      return Positioned(
                                        top: top,
                                        left: 2,
                                        right: 2,
                                        child: eventWidget,
                                      );
                                    }

                                    // For draggable events
                                    return Positioned(
                                      top: top,
                                      left: 2,
                                      right: 2,
                                      child: Draggable<EventInstance>(
                                        data: event,
                                        feedback: Material(
                                          elevation: 4,
                                          child: SizedBox(
                                            width: MediaQuery.of(context).size.width / 8,
                                            child: _buildEventCard(event),
                                          ),
                                        ),
                                        childWhenDragging: Container(
                                          height: height,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.withOpacity(0.5),
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: eventWidget,
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}