import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';

class TimeGrid extends StatefulWidget {
  final DateTime date;
  final List<TimeSlot> selectedSlots;
  final Function(DateTime, int, int) onSlotSelected;
  final Function(DateTime, int, int)? onSlotRemoved;

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
  bool _isRemoving = false;
  int? _dragStartHour;
  int? _dragEndHour;
  static const startHour = 6;
  static const endHour = 24;
  bool _initialSelectionState = false;
  double _cellHeight = 32.0;

  // Track last selected state for better drag handling
  bool _lastSelectedState = false;

  bool _isSlotSelected(int hour) {
    return widget.selectedSlots.any((slot) =>
    slot.date.year == widget.date.year &&
        slot.date.month == widget.date.month &&
        slot.date.day == widget.date.day &&
        hour >= slot.startHour &&
        hour < slot.endHour);
  }

  void _handleDragStart(int hour, bool isSelected, {bool fromHeader = false}) {
    _initialSelectionState = isSelected;
    _lastSelectedState = isSelected;
    setState(() {
      _isDragging = true;
      _isRemoving = isSelected && !fromHeader;
      _dragStartHour = hour;
      _dragEndHour = hour;
    });
  }

  void _handleDragUpdate(int hour) {
    if (!_isDragging) return;

    // Ensure hour is within bounds
    final boundedHour = hour.clamp(startHour, endHour - 1);

    setState(() {
      _dragEndHour = boundedHour;
    });
  }

  void _handleDragEnd() {
    if (!_isDragging || _dragStartHour == null || _dragEndHour == null) return;

    final startHour = min(_dragStartHour!, _dragEndHour!);
    final endHour = max(_dragStartHour!, _dragEndHour!) + 1;

    // Handle selection/deselection
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

  void _handleHourCellTap(int hour) {
    final isSelected = _isSlotSelected(hour);
    if (isSelected) {
      widget.onSlotRemoved?.call(widget.date, hour, hour + 1);
    } else {
      widget.onSlotSelected(widget.date, hour, hour + 1);
    }
  }

  void _selectEntireColumn() {
    final isAnySelected = List.generate(endHour - startHour, (index) => startHour + index)
        .any((hour) => _isSlotSelected(hour));

    if (isAnySelected) {
      // Find all selected slots for this day and remove them
      for (var slot in widget.selectedSlots.where((slot) =>
      slot.date.year == widget.date.year &&
          slot.date.month == widget.date.month &&
          slot.date.day == widget.date.day)) {
        widget.onSlotRemoved?.call(widget.date, slot.startHour, slot.endHour);
      }
    } else {
      // Select the entire day
      widget.onSlotSelected(widget.date, startHour, endHour);
    }
  }

  Widget _buildHourCell(int hour) {
    final isSelected = _isSlotSelected(hour);
    final isInDragRange = _isDragging &&
        _dragStartHour != null &&
        _dragEndHour != null &&
        (hour >= min(_dragStartHour!, _dragEndHour!) &&
            hour <= max(_dragStartHour!, _dragEndHour!));

    Color? backgroundColor;
    if (isInDragRange) {
      backgroundColor = _isRemoving
          ? Colors.red.withOpacity(0.3)
          : Theme.of(context).colorScheme.primary.withOpacity(0.3);
    } else if (isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.3);
    }

    return GestureDetector(
      onTapDown: (_) {
        _handleDragStart(hour, isSelected);
      },
      onTapUp: (_) {
        if (!_isDragging) {
          _handleHourCellTap(hour);
        } else {
          _handleDragEnd();
        }
      },
      onVerticalDragStart: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final currentHour = startHour + (localPosition.dy ~/ _cellHeight);
        if (currentHour >= startHour && currentHour < endHour) {
          _handleDragStart(currentHour, _isSlotSelected(currentHour));
        }
      },
      onVerticalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newHour = startHour + (localPosition.dy ~/ _cellHeight);
        _handleDragUpdate(newHour);
      },
      onVerticalDragEnd: (_) => _handleDragEnd(),
      onHorizontalDragStart: (details) {
        _handleDragStart(hour, isSelected);
      },
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newHour = startHour + (localPosition.dy ~/ _cellHeight);
        _handleDragUpdate(newHour);
      },
      onHorizontalDragEnd: (_) => _handleDragEnd(),
      child: Container(
        height: _cellHeight,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1a4966)),
          color: backgroundColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with date that can select/deselect entire column
        GestureDetector(
          onTap: _selectEntireColumn,
          child: Container(
            height: _cellHeight,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1a4966)),
              color: const Color(0xFFec4755),
            ),
            child: Center(
              child: Text(
                DateFormat('E\nMMM d').format(widget.date),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // Time slots
        ...List.generate(endHour - startHour, (index) {
          final hour = startHour + index;
          return _buildHourCell(hour);
        }),
      ],
    );
  }
}