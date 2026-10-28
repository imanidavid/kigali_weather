import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather.dart';

const _selectedCityKey = 'selected_city';

String _weatherKey(City city) => 'weather_${city.name}';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Weather? weather;
  bool loading = true;
  String? error;
  bool offline = false;
  City selectedCity = cities.first;
  bool _selectionTouched = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _restoreCity();
  }

  Future<void> _restoreCity() async {
    var restored = cities.first;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_selectedCityKey);
      restored = cities.firstWhere(
        (city) => city.name == savedName,
        orElse: () => cities.first,
      );
    } catch (_) {}

    if (!mounted || _selectionTouched) return;
    setState(() {
      selectedCity = restored;
    });
    await load();
  }

  Future<void> _saveSelectedCity(City city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedCityKey, city.name);
    } catch (_) {}
  }

  Future<void> _saveWeather(City city, Weather weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_weatherKey(city), jsonEncode(weather.toJson()));
    } catch (_) {}
  }

  Future<Weather?> _loadCachedWeather(City city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_weatherKey(city));
      if (saved == null) return null;
      return Weather.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectCity(City city) async {
    _selectionTouched = true;
    setState(() {
      selectedCity = city;
      weather = null;
      loading = true;
      error = null;
      offline = false;
    });

    await _saveSelectedCity(city);
    if (!mounted || city.name != selectedCity.name) return;
    await load();
  }

  Future<void> load() async {
    final city = selectedCity;
    final requestId = ++_requestId;

    setState(() {
      loading = true;
      error = null;
      offline = false;
    });

    try {
      final result = await fetchWeather(city);
      if (!mounted || requestId != _requestId) return;

      await _saveWeather(city, result);
      if (!mounted || requestId != _requestId) return;

      setState(() {
        weather = result;
        loading = false;
        error = null;
        offline = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      final cached = await _loadCachedWeather(city);
      if (!mounted || requestId != _requestId) return;

      setState(() {
        loading = false;
        if (cached == null) {
          weather = null;
          error = 'Could not load the weather. Check your internet connection.';
          offline = false;
        } else {
          weather = cached;
          error = null;
          offline = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${selectedCity.name} Weather')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final city in cities)
                      ChoiceChip(
                        label: Text(city.name),
                        selected: city.name == selectedCity.name,
                        onSelected: (_) => _selectCity(city),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loading && weather == null)
                      const SizedBox(
                        height: 360,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error != null)
                      _ErrorView(message: error!, onRetry: load)
                    else if (weather != null)
                      _WeatherCard(weather: weather!, offline: offline),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather, required this.offline});

  final Weather weather;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (offline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline: showing the weather saved at '
                      '${formatTime(weather.time)}',
                      style: TextStyle(color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconFor(weather.code),
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  '${weather.temperature.round()}°C',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(describe(weather.code), style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _Detail(
                        icon: Icons.water_drop,
                        label: 'Humidity',
                        value: '${weather.humidity}%',
                      ),
                    ),
                    Expanded(
                      child: _Detail(
                        icon: Icons.air,
                        label: 'Wind',
                        value: '${weather.wind.toStringAsFixed(1)} km/h',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Updated at ${formatTime(weather.time)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

String formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

IconData iconFor(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if (code >= 51) return Icons.water_drop;
  return Icons.help_outline;
}
