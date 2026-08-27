import 'dart:math';

enum EventStatus {
  scheduled,
  pending,
  completed,
}

class Event {
  String id;
  String name;
  DateTime date;
  EventStatus status;

  Event({
    String? id,
    required this.name,
    required this.date,
    this.status = EventStatus.scheduled,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(1000).toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'status': status.index,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      date: DateTime.parse(json['date']),
      status: EventStatus.values[json['status'] ?? 0],
    );
  }
}
