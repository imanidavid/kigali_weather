// ignore_for_file: avoid_print

import 'package:kigali_weather/weather.dart';

void main() async {
  print('Asking the weather server...');
  final weather = await fetchWeather(cities.first);
  print(
    'Kigali: ${weather.temperature}°C, humidity ${weather.humidity}%, wind ${weather.wind} km/h, code ${weather.code}',
  );
}
