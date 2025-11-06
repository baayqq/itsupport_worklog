import 'package:flutter/foundation.dart';

class Reminder {
  final int? id;
  final String taskTitle;
  final String? locationDetail;
  final String? instructionSource;
  /// ISO 8601 formatted date-time string
  final String dueDate;
  final bool isCompleted;

  const Reminder({
    this.id,
    required this.taskTitle,
    this.locationDetail,
    this.instructionSource,
    required this.dueDate,
    this.isCompleted = false,
  });

  Reminder copyWith({
    int? id,
    String? taskTitle,
    String? locationDetail,
    String? instructionSource,
    String? dueDate,
    bool? isCompleted,
  }) {
    return Reminder(
      id: id ?? this.id,
      taskTitle: taskTitle ?? this.taskTitle,
      locationDetail: locationDetail ?? this.locationDetail,
      instructionSource: instructionSource ?? this.instructionSource,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_title': taskTitle,
      'location_detail': locationDetail,
      'instruction_source': instructionSource,
      'due_date': dueDate,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      taskTitle: map['task_title'] as String? ?? '',
      locationDetail: map['location_detail'] as String?,
      instructionSource: map['instruction_source'] as String?,
      dueDate: map['due_date'] as String? ?? '',
      isCompleted: (map['is_completed'] is int)
          ? (map['is_completed'] as int) == 1
          : (map['is_completed'] as bool? ?? false),
    );
  }

  @override
  String toString() {
    return 'Reminder(id: $id, taskTitle: $taskTitle, dueDate: $dueDate, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Reminder &&
        other.id == id &&
        other.taskTitle == taskTitle &&
        other.locationDetail == locationDetail &&
        other.instructionSource == instructionSource &&
        other.dueDate == dueDate &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      taskTitle,
      locationDetail,
      instructionSource,
      dueDate,
      isCompleted,
    );
  }
}