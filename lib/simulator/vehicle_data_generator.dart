import 'package:random_string/random_string.dart';
import 'package:vin_decoder/vin_decoder.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class VehicleDataGenerator {
  static final _singleton = VehicleDataGenerator._internal();
  final _random = Random();
  final _uuid = Uuid();
  final _vinGenerator = VINGenerator();

  factory VehicleDataGenerator() {
    return _singleton;
  }

  VehicleDataGenerator._internal();

  String vin() {
    return _vinGenerator.generate();
  }

  String licensePlate() {
    return randomAlpha(3).toUpperCase() + '-' + randomNumeric(3).toString();
  }

  double odometer() {
    return _random.nextInt(150000) + _random.nextDouble();
  }

  int id() {
    return _random.nextInt(1000);
  }

  String journeyId() {
    return _uuid.v4();
  }
}
