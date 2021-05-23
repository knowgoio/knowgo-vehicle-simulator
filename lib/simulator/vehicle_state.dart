import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:vin_decoder/vin_decoder.dart';

import 'vehicle_data_generator.dart';

void initVehicleInfo(knowgo.Auto auto) {
  var generator = VehicleDataGenerator();
  var autoConfig = knowgo.Auto();

  // As VehicleSimulator may be instantiated in separate isolates,
  // make sure that the service in the main isolate is reachable.
  if (serviceLocator.isRegistered<SettingsService>() == true) {
    var settingsService = serviceLocator.get<SettingsService>();
    autoConfig = settingsService.autoConfig;
  }

  if (autoConfig.name != null) {
    auto.name = autoConfig.name;
  } else {
    auto.name = 'KnowGo Vehicle Simulator';
  }

  if (autoConfig.VIN != null) {
    auto.VIN = autoConfig.VIN;
  } else {
    auto.VIN = generator.vin();
  }

  if (autoConfig.licensePlate != null) {
    auto.licensePlate = autoConfig.licensePlate;
  } else {
    auto.licensePlate = generator.licensePlate();
  }

  auto.year = VIN(number: auto.VIN).getYear();

  if (autoConfig.odometer != null) {
    auto.odometer = autoConfig.odometer;
  } else {
    auto.odometer = 0; // This will be updated by the event loop
  }

  if (autoConfig.driverID != null) {
    auto.driverID = autoConfig.driverID;
  } else {
    auto.driverID = generator.id();
  }

  if (autoConfig.autoID != null) {
    auto.autoID = autoConfig.autoID;
  } else {
    auto.autoID = generator.id();
  }

  auto.fuelCapacity = "40L";
}

void initVehicleState(knowgo.Event state) {
  var generator = VehicleDataGenerator();
  var initEvent = knowgo.Event();

  // As VehicleSimulator may be instantiated in separate isolates,
  // make sure that the service in the main isolate is reachable.
  if (serviceLocator.isRegistered<SettingsService>() == true) {
    var settingsService = serviceLocator.get<SettingsService>();
    initEvent = settingsService.initEvent;
    if (initEvent.odometer == null) {
      initEvent.odometer = settingsService.autoConfig.odometer;
    }
  }

  state.transmissionGearPosition = knowgo.TransmissionGearPosition.first;
  state.ignitionStatus = knowgo.IgnitionStatus.off;
  state.windshieldWiperStatus = false;
  state.headlampStatus = false;
  state.doorStatus = knowgo.DoorStatus.all_unlocked;
  state.latitude = 48.020250;
  state.longitude = 11.584850;
  state.acceleratorPedalPosition = 10.0;
  state.brakePedalPosition = 0.0;
  state.bearing = 0;

  if (initEvent.odometer != null) {
    state.odometer = initEvent.odometer;
  } else {
    state.odometer = generator.odometer();
  }

  state.vehicleSpeed ??= 0;
  state.steeringWheelAngle = 0;
  state.engineSpeed = 0;
  state.fuelLevel = 100.0;
  state.fuelConsumedSinceRestart = 0.0;
}

void updateVehicleState(knowgo.Event state, knowgo.Event update) {
  if (update.journeyID != null) {
    state.journeyID = update.journeyID;
  }
  if (update.steeringWheelAngle != null) {
    state.steeringWheelAngle = update.steeringWheelAngle;
  }
  if (update.torqueAtTransmission != null) {
    state.torqueAtTransmission = update.torqueAtTransmission;
  }
  if (update.engineSpeed != null) {
    state.engineSpeed = update.engineSpeed;
  }
  if (update.vehicleSpeed != null) {
    state.vehicleSpeed = update.vehicleSpeed;
  }
  if (update.acceleratorPedalPosition != null) {
    state.acceleratorPedalPosition = update.acceleratorPedalPosition;
  }
  if (update.parkingBrakeStatus != null) {
    state.parkingBrakeStatus = update.parkingBrakeStatus;
  }
  if (update.brakePedalPosition != null) {
    state.brakePedalPosition = update.brakePedalPosition;
  }
  if (update.transmissionGearPosition != null) {
    state.transmissionGearPosition = update.transmissionGearPosition;
  }
  if (update.gearLeverPosition != null) {
    state.gearLeverPosition = update.gearLeverPosition;
  }
  if (update.odometer != null) {
    state.odometer = update.odometer;
  }
  if (update.ignitionStatus != null) {
    state.ignitionStatus = update.ignitionStatus;
  }
  if (update.fuelLevel != null) {
    state.fuelLevel = update.fuelLevel;
  }
  if (update.fuelConsumedSinceRestart != null) {
    state.fuelConsumedSinceRestart = update.fuelConsumedSinceRestart;
  }
  if (update.doorStatus != null) {
    state.doorStatus = update.doorStatus;
  }
  if (update.headlampStatus != null) {
    state.headlampStatus = update.headlampStatus;
  }
  if (update.highBeamStatus != null) {
    state.highBeamStatus = update.highBeamStatus;
  }
  if (update.windshieldWiperStatus != null) {
    state.windshieldWiperStatus = update.windshieldWiperStatus;
  }
  if (update.latitude != null) {
    state.latitude = update.latitude;
  }
  if (update.longitude != null) {
    state.longitude = update.longitude;
  }
  if (update.bearing != null) {
    state.bearing = update.bearing;
  }
  if (update.accuracy != null) {
    state.accuracy = update.accuracy;
  }
  if (update.timestamp != null) {
    state.timestamp = update.timestamp;
  }
  if (update.accelX != null) {
    state.accelX = update.accelX;
  }
  if (update.accelY != null) {
    state.accelY = update.accelY;
  }
  if (update.accelZ != null) {
    state.accelZ = update.accelZ;
  }
  if (update.gyroX != null) {
    state.gyroX = update.gyroX;
  }
  if (update.gyroY != null) {
    state.gyroY = update.gyroY;
  }
  if (update.gyroZ != null) {
    state.gyroZ = update.gyroZ;
  }
}
