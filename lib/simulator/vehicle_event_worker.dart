// Web worker implementation of the vehicle event loop
@JS()
library workers;

import 'dart:async';
import 'dart:collection';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:knowgo/api.dart' as knowgo;

import 'vehicle_data_calculators.dart';

@JS('Object.keys')
external List<String> _getKeysOfObject(jsObject);

@JS('self')
external DedicatedWorkerGlobalScope get self;

@JS("JSON.parse")
external dynamic jsonParse(text, [reviver]);

// Map<String, dynamic> adapter for JS Objects, cribbed from:
// https://github.com/dart-lang/sdk/issues/28194#issuecomment-269051789
class JsMap<V> extends MapMixin<String, dynamic> {
  var _jsObject;

  JsMap(this._jsObject);

  @override
  V operator [](Object? key) => getProperty(_jsObject, key.toString());

  @override
  operator []=(String key, dynamic value) =>
      setProperty(_jsObject, key.toString(), value);

  @override
  remove(Object? key) {
    throw "Not implemented yet";
  }

  @override
  Iterable<String> get keys => _getKeysOfObject(_jsObject);

  @override
  bool containsKey(Object? key) => hasProperty(_jsObject, key!);

  @override
  void clear() {
    throw "Not implemented yet";
  }
}

void main() {
  var calculator = VehicleDataCalculator();

  // Wait for the current vehicle state to be passed in
  self.onMessage.listen((msg) {
    // As the passed in Dart objects are opaque to JS, a few steps are required
    // in order to get the data into the format we need on both the Dart and JS
    // sides:
    //
    // 1. Dart objects are passed in as JSON using Dart's jsonEncode()
    // 2. The JS-native JSON.parse() parses this into a JS Object
    // 3. The JS Object is converted to a Map<String, dynamic> with the JsMap mixin
    // 4. The resulting map is handed off to the Dart class .fromJson()
    //    constructor, and the object is recreated using the native Dart class.
    // 5. JS->Dart communication uses the class-specific .toJson() converter,
    //    which is then converted back on the Dart side with the .fromJson()
    //    constructor.
    //
    // Using this approach, we can avoid creating a JS-native representation of
    // the underlying Dart class.
    var infoMap = JsMap(jsonParse(msg.data[0]));
    var stateMap = JsMap(jsonParse(msg.data[2]));
    int eventId = msg.data[1];

    var info = knowgo.Auto.fromJson(infoMap);
    var state = knowgo.Event.fromJson(stateMap);

    Timer.periodic(Duration(seconds: 1), (timer) {
      var event = state;

      event.engineSpeed = calculator.engineSpeed(state);
      event.vehicleSpeed = calculator.vehicleSpeed(info, state);
      event.latitude = calculator.latitude(state);
      event.longitude = calculator.longitude(state);
      event.bearing = calculator.heading(state);
      event.torqueAtTransmission = calculator.torque(state);
      event.fuelConsumedSinceRestart = calculator.fuelConsumed(state);
      event.fuelLevel = calculator.fuelLevel(info, state);
      event.transmissionGearPosition =
          calculator.gearPosition(info, state, event.vehicleSpeed);
      event.autoID = info.autoID;
      event.eventID = eventId++;
      event.odometer = calculator.odometer(state);
      event.timestamp = DateTime.now();

      // Cache updated state for next iteration
      state = event;

      // Send back the event
      self.postMessage(event.toJson(), null);
    });
  });
}
