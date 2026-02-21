import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimesData {
  /// ================= STORAGE KEYS =================
  static const _timesKey = "prayer_times";
  static const _userSetKey = "user_set_azan";

  static List<TimeOfDay> times = [];

  /// ================= INIT =================
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userSet = prefs.getBool(_userSetKey) ?? false;

    if (userSet) {
      // 👤 User ne custom set kiya hai → cache load karo
      await _loadFromCache();
    } else {
      // 📡 First time ya reset ke baad → API se lao
      await _fetchFromAPI();
    }
  }

  /// ================= USER SAVE =================
  static Future<void> saveUserTimes(List<TimeOfDay> newTimes) async {
    times = newTimes;

    final prefs = await SharedPreferences.getInstance();
    await _saveToCache();

    // mark user priority TRUE
    await prefs.setBool(_userSetKey, true);
  }

  /// ================= RESET =================
  static Future<void> resetToAPI() async {
    final prefs = await SharedPreferences.getInstance();

    // user priority remove
    await prefs.setBool(_userSetKey, false);

    // fresh API load
    await _fetchFromAPI();
  }

  /// ================= LOCATION =================
  static Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  /// ================= API =================
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

      times = [
        _add30(_parse(timings["Fajr"])),
        _add30(_parse(timings["Dhuhr"])),
        _add30(_parse(timings["Asr"])),
        _add30(_parse(timings["Maghrib"])),
        _add30(_parse(timings["Isha"])),
      ];

      await _saveToCache();
    } catch (e) {
      debugPrint("API Error: $e");
    }
  }

  /// ================= HELPERS =================
  static TimeOfDay _parse(String time) {
    final clean = time.split(" ")[0];
    final parts = clean.split(":");

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  /// 🔥 30 MIN ADD
  static TimeOfDay _add30(TimeOfDay t) {
    int total = t.hour * 60 + t.minute + 20;

    return TimeOfDay(
      hour: (total ~/ 60) % 24,
      minute: total % 60,
    );
  }

  static Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();

    final list = times
        .map((t) =>
            "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}")
        .toList();

    await prefs.setStringList(_timesKey, list);
  }

  static Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_timesKey);

    if (list == null) return;

    times = list.map((e) {
      final p = e.split(":");
      return TimeOfDay(
        hour: int.parse(p[0]),
        minute: int.parse(p[1]),
      );
    }).toList();
  }
}
