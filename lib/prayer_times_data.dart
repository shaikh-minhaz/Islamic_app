import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimesData {
  /// Final usable prayer times (with +20 min)
  static List<TimeOfDay> times = [
    const TimeOfDay(hour: 5, minute: 0),
    const TimeOfDay(hour: 12, minute: 30),
    const TimeOfDay(hour: 16, minute: 30),
    const TimeOfDay(hour: 18, minute: 30),
    const TimeOfDay(hour: 20, minute: 0),
  ];

  ////////////////////////////////////////////////////////////
  /// MAIN FUNCTION → call this once at app start
  ////////////////////////////////////////////////////////////

  static Future<void> init() async {
    await _loadFromCache(); // offline fallback
    await _fetchFromAPI(); // try online refresh
  }

  ////////////////////////////////////////////////////////////
  /// GET USER LOCATION
  ////////////////////////////////////////////////////////////

  static Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  ////////////////////////////////////////////////////////////
  /// FETCH FROM API
  ////////////////////////////////////////////////////////////

  static Future<void> _fetchFromAPI() async {
    try {
      final position = await _getLocation();
      if (position == null) return;

      final url = Uri.parse(
        "https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=2",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      final timings = data["data"]["timings"];

      /// Convert + add 20 minutes
      times = [
        _add20(_parse(timings["Fajr"])),
        _add20(_parse(timings["Dhuhr"])),
        _add20(_parse(timings["Asr"])),
        _add20(_parse(timings["Maghrib"])),
        _add20(_parse(timings["Isha"])),
      ];

      await _saveToCache();
    } catch (_) {
      // ignore → offline will work
    }
  }

  ////////////////////////////////////////////////////////////
  /// PARSE "HH:mm"
  ////////////////////////////////////////////////////////////

  static TimeOfDay _parse(String time) {
    final parts = time.split(":");
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  ////////////////////////////////////////////////////////////
  /// ADD +20 MIN
  ////////////////////////////////////////////////////////////

  static TimeOfDay _add20(TimeOfDay t) {
    int total = t.hour * 60 + t.minute + 20;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  ////////////////////////////////////////////////////////////
  /// SAVE TO LOCAL STORAGE
  ////////////////////////////////////////////////////////////

  static Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();

    final list = times.map((t) => "${t.hour}:${t.minute}").toList();
    await prefs.setStringList("prayer_times", list);
  }

  ////////////////////////////////////////////////////////////
  /// LOAD FROM CACHE (offline support)
  ////////////////////////////////////////////////////////////

  static Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList("prayer_times");

    if (list == null) return;

    times = list.map((e) {
      final p = e.split(":");
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }).toList();
  }
}
