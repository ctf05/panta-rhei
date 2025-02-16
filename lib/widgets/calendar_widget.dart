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

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(widget.initialDate);
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

  Widget _buildTimeColumn() {
    return Column(
      children: [
        // Header spacer
        Container(
          height: 60,
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
        // Hour cells
        Expanded(
          child: ListView.builder(
            itemCount: endHour - startHour,
            itemBuilder: (context, index) {
              final hour = startHour + index;
              return GestureDetector(
                onTap: () => widget.onHourSelected?.call(hour),
                child: Container(
                  height: 60,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(DateTime day) {
    final dayEvents = widget.events.where((event) => 
      event.date.year == day.year && 
      event.date.month == day.month && 
      event.date.day == day.day
    ).toList();

    return Column(
      children: [
        // Day header
        Container(
          height: 60,
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
        // Hour grid with events
        Expanded(
          child: SingleChildScrollView(
            controller: ScrollController(), // Add a shared scroll controller
            child: Stack(
              children: [
                // Hour grid
                Column(
                  children: List.generate(endHour - startHour, (index) {
                    final hour = startHour + index;
                    return GestureDetector(
                      onTap: () {
                        if (widget.isEditable) {
                          widget.onDaySelected?.call(day);
                        }
                      },
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1a4966)),
                          color: day.isBefore(DateTime.now()) && !widget.isEditable
                              ? Colors.grey.withOpacity(0.1)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
                // Events
                ...dayEvents.map((event) {
                  final top = (event.startHour - startHour) * 60.0;
                  final height = (event.endHour - event.startHour) * 60.0;

                  return Positioned(
                    top: top,
                    left: 2,
                    right: 2,
                    child: widget.allowDragDrop && widget.isEditable
                        ? Draggable<EventInstance>(
                      data: event,
                      feedback: Material(
                        elevation: 4,
                        child: _buildEventCard(event, height),
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
                      child: _buildEventCard(event, height),
                    )
                        : GestureDetector(
                      onTap: () => widget.onEventTapped?.call(event),
                      child: _buildEventCard(event, height),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventInstance event, double height) {
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
          if (height > 60 && event.assignedPeople.isNotEmpty)
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

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 80,
                child: _buildTimeColumn(),
              ),
              // Day columns
              Expanded(
                child: Row(
                  children: weekDays.map((day) {
                    return Expanded(
                      child: DragTarget<EventInstance>(
                        onWillAccept: (data) => widget.isEditable && widget.allowDragDrop,
                        onAccept: (eventInstance) {
                          final hour = ((MediaQuery.of(context).size.height - 60) / 2 / 60).floor() + startHour;
                          widget.onEventMoved?.call(eventInstance, day, hour);
                        },
                        builder: (context, candidateData, rejectedData) {
                          return _buildDayColumn(day);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}