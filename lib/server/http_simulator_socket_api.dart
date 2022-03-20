import 'dart:convert';

import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VehicleSimulatorSocketApi {
  final VehicleSimulator vehicleSimulator;

  VehicleSimulatorSocketApi({required this.vehicleSimulator});

  Handler get router {
    return webSocketHandler((WebSocketChannel socket) {
      // Pass event updates directly through to the web socket
      vehicleSimulator.eventStream
          .listen((event) => socket.sink.add(json.encode(event)));
    });
  }
}
