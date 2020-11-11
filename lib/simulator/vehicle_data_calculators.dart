import 'dart:math';

import 'package:knowgo/api.dart' as knowgo;
import 'package:vector_math/vector_math.dart';

class VehicleDataCalculator {
  int _tankCapacity(knowgo.Auto auto) {
    final numRegex = RegExp(r'[0-9]');
    final capacity = numRegex.matchAsPrefix(auto.fuelCapacity).group(0);
    return int.parse(capacity);
  }

  double engineSpeed(knowgo.Event state) {
    return 16382 *
        state.vehicleSpeed /
        (100.0 * state.transmissionGearPosition.gearNumber);
  }

  double vehicleSpeed(knowgo.Event state) {
    const airDragCoeff = 0.000008;
    const engineDragCoeff = 0.0004;
    const brakeConstant = 0.1;
    const engineV0Force = 20;

    var airDrag = (state.vehicleSpeed * 3) * airDragCoeff;
    var engineDrag = state.engineSpeed * engineDragCoeff;
    var engineForce = 0.0;
    var gear = state.transmissionGearPosition.gearNumber;

    if (state.ignitionStatus == knowgo.IgnitionStatus.run) {
      engineForce =
          (engineV0Force * state.acceleratorPedalPosition / (50 * gear));
    }

    var acceleration = engineForce -
        airDrag -
        engineDrag -
        (state.brakePedalPosition * brakeConstant);

    if ((acceleration + state.vehicleSpeed) < 0.0) {
      acceleration = -state.vehicleSpeed;
    }

    var speed = state.vehicleSpeed + acceleration;

    // Cap speed per gear for manual transmission type
    if (gear == 1 && speed > 20) {
      return 20;
    } else if (gear == 2 && speed > 40) {
      return 40;
    } else if (gear == 3 && speed > 55) {
      return 55;
    } else if (gear == 4 && speed > 70) {
      return 70;
    }

    // Cap overall speed at 200kph
    if (speed > 200) {
      return 200;
    }

    return speed;
  }

  double odometer(knowgo.Event state) {
    var kphToKps = 60 * 60;
    return state.odometer + (state.vehicleSpeed / kphToKps);
  }

  double fuelConsumed(knowgo.Event state) {
    var maxFuelConsumption = 0.0015; // Max consumption in Litres per second
    var idleFuelConsumption = 0.000015; // Idle fuel consumption rate

    if (state.ignitionStatus != knowgo.IgnitionStatus.run) {
      return 0.0;
    }

    return state.fuelConsumedSinceRestart +
        idleFuelConsumption +
        (maxFuelConsumption * (state.acceleratorPedalPosition / 100));
  }

  double fuelLevel(knowgo.Auto auto, knowgo.Event state) {
    final capacity = _tankCapacity(auto);
    return state.fuelLevel *
        ((capacity - state.fuelConsumedSinceRestart) / capacity);
  }

  double torque(knowgo.Event state) {
    const engineToTorque = 500.0 / 16382.0;
    var gear = state.transmissionGearPosition.prevGear;
    if (gear == knowgo.TransmissionGearPosition.neutral) {
      gear = knowgo.TransmissionGearPosition.first;
    }

    var ratio = 1 - (gear.gearNumber * .1);
    var drag = state.engineSpeed * engineToTorque;
    var power = state.acceleratorPedalPosition * 15 * ratio;

    if (state.ignitionStatus == knowgo.IgnitionStatus.run) {
      return power - drag;
    }

    return -drag;
  }

  double heading(knowgo.Event state) {
    // Stay on the present heading if the wheel angle is 0
    if (state.steeringWheelAngle == 0) {
      return state.bearing;
    }

    // The ratio of steering wheel degrees to wheel degrees, typically in the
    // range of 12-20 for passenger vehicles.
    const steeringRatio = 12;
    var wheelAngle = state.steeringWheelAngle / steeringRatio;
    var wheelAngleRadians = radians(wheelAngle);
    var calcAngle = -wheelAngleRadians;

    if (wheelAngle < 0) {
      calcAngle -= pi / 2;
    } else if (wheelAngle > 0) {
      calcAngle += pi / 2;
    }

    var turningCircumference = 0.028 * tan(calcAngle);
    var distance = state.vehicleSpeed / 3600;
    var delta = (distance / turningCircumference) * 2 * pi;
    var heading = radians(state.bearing) + delta;

    while (heading >= (2 * pi)) {
      heading -= (2 * pi);
    }
    while (heading < 0) {
      heading += (2 * pi);
    }

    return heading * (180 / pi);
  }

  double latitude(knowgo.Event state) {
    const earthMeridionalCircumferenceKm = 40008.0;
    const kmPerDegree = earthMeridionalCircumferenceKm / 360.0;

    var distance = state.vehicleSpeed / 3600;
    var northSouthDistance = distance * cos(state.bearing);

    var delta = northSouthDistance / kmPerDegree;

    return state.latitude + delta;
  }

  double longitude(knowgo.Event state) {
    const earthEquatorialCircumferenceKm = 40075.0;
    const kmPerDegreeEquator = earthEquatorialCircumferenceKm / 360.0;

    var distance = state.vehicleSpeed / 3600;
    var eastWestDistance = distance * sin(state.bearing);

    var latRadians = radians(state.latitude);
    var kmPerDegree = (kmPerDegreeEquator * sin(latRadians)).abs();
    var delta = eastWestDistance;

    if (state.latitude != 0) {
      delta /= kmPerDegree;
    }

    var adjusted = state.longitude + delta;

    while (adjusted >= 180.0) {
      adjusted -= 360;
    }
    while (adjusted < -180) {
      adjusted += 360;
    }

    return adjusted;
  }
}
