import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_simulator_desktop/services.dart';

import 'vehicle_data_generator.dart';
import 'vehicle_event_loop.dart';
import 'vehicle_state.dart';

enum VehicleSimulatorCommands {
  Start,
  Stop,
  Update,
}

/// Vehicle Simulator base class.
class VehicleSimulator extends ChangeNotifier {
  // Vehicle Events Isolate
  Isolate _eventIsolate;

  // HTTP Server ReceivePort
  final ReceivePort serverReceivePort;
  SendPort _serverSendPort;

  final simulatorReceivePort = ReceivePort();

  VehicleSimulator([this.serverReceivePort]) {
    initVehicleInfo(info);
    initVehicleState(state);
    journey.autoID = info.autoID;
    journey.driverID = info.driverID;
    _writeConsoleMessage('Waiting for simulator to start..');
  }

  // Information about the generated Vehicle
  knowgo.Auto info = knowgo.Auto();

  // The current Journey the Vehicle is on
  knowgo.Journey journey = knowgo.Journey();

  // The current state of the Vehicle
  knowgo.Event state = knowgo.Event();

  // Free-running event counter for generating event IDs
  static int _eventCounter = 0;

  // Simulator state
  bool running = false;

  void _writeConsoleMessage(String msg) {
    // As VehicleSimulator may be instantiated in separate isolates,
    // make sure that the service in the main isolate is reachable.
    if (serviceLocator.isRegistered<ConsoleService>() == false) {
      return;
    }
    var _consoleService = serviceLocator.get<ConsoleService>();
    _consoleService.write(msg);
  }

  Future<void> initHttpSync() async {
    simulatorReceivePort.listen((data) {
      if (data is SendPort) {
        _serverSendPort = data;
        _serverSendPort.send([info, state, null]);
      } else {
        // Handle updates to the simulator from the HTTP Server
        var command = data[0];
        switch (command) {
          case VehicleSimulatorCommands.Start:
            start();
            break;
          case VehicleSimulatorCommands.Stop:
            stop();
            break;
          case VehicleSimulatorCommands.Update:
            update(data[1]);
            break;
        }
      }
    });
  }

  // The Vehicle Simulator uses a pair of Send/ReceivePorts in order to
  // enable bi-directional communication with the event isolate. As we can not
  // share memory directly between the main and event isolates, we instead have
  // to rely on message passing, and so pass through a snapshot of the vehicle
  // state to the event isolate and then wait to receive back event updates
  // derived from this state. Vehicle events in the main isolate are then
  // updated on receipt of periodic messages from the event isolate.
  Future<void> start() async {
    var _consoleService = serviceLocator.get<ConsoleService>();
    var _receivePort = ReceivePort();
    SendPort _sendPort;

    if (running == false) {
      running = true;

      // Spawn the event isolate
      _eventIsolate =
          await Isolate.spawn(vehicleEventLoop, _receivePort.sendPort);

      _receivePort.listen((data) {
        // Wait for the event isolate to open up a ReceivePort and then send
        // through reference to the current vehicle info, last eventID and state.
        if (data is SendPort) {
          _sendPort = data;
          _sendPort.send([info, _eventCounter++, state]);
        } else {
          // Receive event updates from the event isolate
          var update = data;

          // Sync the event counter
          _eventCounter++;

          // Synchronize vehicle state
          info.odometer = num.parse((update.odometer).toStringAsFixed(2));
          updateVehicleState(state, update);

          // Check if we need to reset the journey
          if (journey.journeyID == null) {
            var generator = VehicleDataGenerator();

            journey.journeyID = generator.journeyId();
            journey.journeyBegin = DateTime.now();
            journey.odometerBegin = info.odometer;
            journey.events = [];
          }

          // Add to event list
          journey.events.add(update);

          // Log event to console
          _consoleService.write(update.toString());

          if (state.fuelLevel <= 0) {
            _writeConsoleMessage('Vehicle is out of fuel, stopping..');
            stop();
          }

          _serverSendPort.send([info, state, journey.events]);
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
    var needsRestart = running;
    stop();
    updateVehicleState(state, update);
    if (needsRestart) {
      await start();
    }
  }
}
