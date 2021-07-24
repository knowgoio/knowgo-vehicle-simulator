import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:uuid/uuid.dart';

final _uuidGenerator = Uuid();

/// An event that is injected into the simulation model at a pre-defined time.
///
/// Each event wraps into a one-shot timer that is scheduled by the
/// [EventInjectorModel] whenever a new journey is started. Any armed timers
/// are cancelled automatically if the journey is stopped before the timers
/// expire.
class TimedEvent {
  /// Time to inject the event relative to the journey start time.
  final Duration injectionTime;
  final VoidCallback callback;
  final EventTrigger trigger;
  final String _id;
  bool _enabled;
  Timer? _timer;

  TimedEvent(
      {required this.injectionTime,
      required this.callback,
      required this.trigger})
      : _id = _uuidGenerator.v4(),
        _enabled = true,
        assert(trigger != EventTrigger.none);

  String get id => _id;

  bool get enabled => _enabled;
  void enable() => _enabled = true;
  void disable() => _enabled = false;

  void schedule() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (_enabled) {
      _timer = Timer(this.injectionTime, this.callback);
    }
  }

  void cancel() {
    _timer?.cancel();
  }

  @override
  String toString() {
    return 'TimedEvent[injectionTime=$injectionTime, trigger=$trigger, id=$_id, enabled=$_enabled]';
  }
}

class EventInjectorModel extends ChangeNotifier {
  static final _singleton = EventInjectorModel._internal();

  // A sorted list of TimedEvents, sorted by their respective injection times.
  final List<TimedEvent> _timedEvents = [];

  factory EventInjectorModel() {
    return _singleton;
  }

  EventInjectorModel._internal();

  UnmodifiableListView<TimedEvent> get events =>
      UnmodifiableListView(_timedEvents);

  /// Get the list of event triggers supported by the injector
  UnmodifiableListView<EventTrigger> get supportedEvents =>
      UnmodifiableListView([
        EventTrigger.none,
        EventTrigger.harsh_acceleration,
        EventTrigger.harsh_braking
      ]);

  void addTimedEvent(TimedEvent timedEvent) {
    _timedEvents.add(timedEvent);

    // Re-sort the list based on injection time
    _timedEvents.sort((a, b) => a.injectionTime.compareTo(b.injectionTime));

    // Trigger UI refresh to re-sort dependent widgets
    notifyListeners();
  }

  void removeTimedEvent(String timedEventId) {
    TimedEvent? timedEvent =
        _timedEvents.firstWhereOrNull((item) => item.id == timedEventId);
    if (timedEvent != null) {
      timedEvent.cancel();
      _timedEvents.removeWhere((item) => item.id == timedEventId);
    }
  }

  void scheduleAll() {
    _timedEvents.forEach((timedEvent) => timedEvent.schedule());
  }

  void descheduleAll() {
    _timedEvents.forEach((timedEvent) => timedEvent.cancel());
  }
}
