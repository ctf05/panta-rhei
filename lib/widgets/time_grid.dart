import 'package:flutter/material.dart';
import '../models/calendar_models.dart';

class TimeGrid extends StatefulWidget {
  final DateTime date;
  final List<TimeSlot> selectedSlots;
  final Function(DateTime, int, int) onSlotSelected;
  final Function(DateTime, int, int)? onSlotRemoved;  // New callback

  const TimeGrid({
    super.key,
    required this.date,
    required this.selectedSlots,
    required this.onSlotSelected,
    this.onSlotRemoved,
  });

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  bool _isDragging = false;
  bool _isRemoving = false;  // New state for removal mode
  int? _dragStartHour;
  int? _dragEndHour;
  static const startHour = 6;
  static const endHour = 24;

  bool _isSlotSelected(int hour) {
    return widget.selectedSlots.any((slot) =>
    slot.date.year == widget.date.year &&
        slot.date.month == widget.date.month &&
        slot.date.day == widget.date.day &&
        hour >= slot.startHour &&
        hour < slot.endHour);
  }

  void _handleDragStart(int hour, bool isSelected) {
    setState(() {
      _isDragging = true;
      _isRemoving = isSelected;  // If starting on a selected slot, we're removing
      _dragStartHour = hour;
      _dragEndHour = hour;
    });
  }

  void _handleDragUpdate(int hour) {
    if (!_isDragging) return;
    setState(() {
      _dragEndHour = hour;
    });
  }

  void _handleDragEnd() {
    if (!_isDragging || _dragStartHour == null || _dragEndHour == null) return;

    final startHour = _dragStartHour!.compareTo(_dragEndHour!) <= 0
        ? _dragStartHour!
        : _dragEndHour!;
    final endHour = _dragStartHour!.compareTo(_dragEndHour!) <= 0
        ? _dragEndHour! + 1
        : _dragStartHour! + 1;

    if (_isRemoving) {
      widget.onSlotRemoved?.call(widget.date, startHour, endHour);
    } else {
      widget.onSlotSelected(widget.date, startHour, endHour);
    }

    setState(() {
      _isDragging = false;
      _isRemoving = false;
      _dragStartHour = null;
      _dragEndHour = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(endHour - startHour, (index) {
        final hour = startHour + index;
        final isSelected = _isSlotSelected(hour);
        final isInDragRange = _isDragging && _dragStartHour != null && _dragEndHour != null &&
            ((hour >= _dragStartHour! && hour <= _dragEndHour!) ||
                (hour >= _dragEndHour! && hour <= _dragStartHour!));

        Color? backgroundColor;
        if (isInDragRange) {
          backgroundColor = _isRemoving
              ? Colors.red.withOpacity(0.3)
              : Theme.of(context).colorScheme.primary.withOpacity(0.3);
        } else if (isSelected) {
          backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.3);
        }

        return GestureDetector(
          onTapDown: (_) => _handleDragStart(hour, isSelected),
          onVerticalDragStart: (_) => _handleDragStart(hour, isSelected),
          onVerticalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final newHour = startHour + (localPosition.dy ~/ 60);
            if (newHour >= startHour && newHour < endHour) {
              _handleDragUpdate(newHour);
            }
          },
          onVerticalDragEnd: (_) => _handleDragEnd(),
          onTapUp: (_) => _handleDragEnd(),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1a4966)),
              color: backgroundColor,
            ),
          ),
        );
      }),
    );
  }
}