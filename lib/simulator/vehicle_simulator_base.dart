import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'vehicle_state.dart';
import 'vehicle_event_loop.dart';

/// Vehicle Simulator base class.
class VehicleSimulator extends ChangeNotifier {
  Isolate _eventIsolate;

  // Information about the generated Vehicle
  final info = knowgo.Auto();

  // The current state of the Vehicle
  knowgo.Event state = knowgo.Event();

  // List of Vehicle events generated
  var events = [];

  // Simulator state
  bool running = false;

  // The Vehicle Simulator uses a pair of Send/ReceivePorts in order to
  // enable bi-directional communication with the event isolate. As we can not
  // share memory directly between the main and event isolates, we instead have
  // to rely on message passing, and so pass through a snapshot of the vehicle
  // state to the event isolate and then wait to receive back event updates
  // derived from this state. Vehicle events in the main isolate are then
  // updated on receipt of periodic messages from the event isolate.
  Future<void> start() async {
    var _receivePort = ReceivePort();
    SendPort _sendPort;

    if (info.VIN == null) {
      initVehicleInfo(info);
      initVehicleState(state);
    }

    if (running == false) {
      running = true;

      // Spawn the event isolate
      _eventIsolate =
          await Isolate.spawn(vehicleEventLoop, _receivePort.sendPort);

      _receivePort.listen((data) {
        // Wait for the event isolate to open up a ReceivePort and then send
        // through reference to the current vehicle info, last eventID and state.
        if (data is SendPort) {
          int nextEventId = 0;
          if (events.length > 0) {
            nextEventId = events.last.eventID + 1;
          }
          _sendPort = data;
          _sendPort.send([info, nextEventId, state]);
        } else {
          // Receive event updates from the event isolate
          var update = data;

          // Synchronize vehicle state
          info.odometer = update.odometer.toInt();
          updateVehicleState(state, update);

          // Add to event list
          events.add(update);

          if (state.fuelLevel <= 0) {
            print('Vehicle is out of fuel, stopping..');
            stop();
          }

          notifyListeners();
        }
      });
    }
  }

  void stop() {
    if (running == true) {
      _eventIsolate.kill(priority: Isolate.immediate);
      running = false;
      _eventIsolate = null;
      notifyListeners();
    }
  }

  Future<void> update(knowgo.Event update) async {
    stop();
    updateVehicleState(state, update);
    await start();
  }
}
