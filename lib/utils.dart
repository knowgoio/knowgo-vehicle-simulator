import 'package:flutter/material.dart';

// Helper to create a custom ColorSwatch, taken from:
// https://medium.com/@filipvk/creating-a-custom-color-swatch-in-flutter-554bcdcb27f3
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  var swatch = Map<int, Color>();
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}

enum DeviceType {
  phone,
  tablet,
}

DeviceType getDeviceType() {
  final data = MediaQueryData.fromWindow(WidgetsBinding.instance!.window);
  return data.size.shortestSide < 600 ? DeviceType.phone : DeviceType.tablet;
}

extension DurationExtensions on Duration {
  String toHoursMinutesSecondsAnnotated() {
    var seconds = this.inSeconds;
    final hours = seconds ~/ Duration.secondsPerHour;
    seconds -= hours * Duration.secondsPerHour;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    seconds -= minutes * Duration.secondsPerMinute;

    final tokens = [];
    if (hours != 0) {
      tokens.add('${hours}h');
    }
    if (minutes != 0) {
      tokens.add('${minutes}m');
    }
    if (seconds != 0) {
      tokens.add('${seconds}s');
    }

    return tokens.join(':');
  }
}

extension StringExtension on String {
  String snakeCaseToSentenceCaseUpper() {
    List<String> newString = [];
    this.split('_').forEach((element) {
      newString.add(element[0].toUpperCase() + element.substring(1));
    });
    return newString.join(' ');
  }

  String toSnakeCase() {
    return this.toLowerCase().replaceAll(' ', '_');
  }
}
