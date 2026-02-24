import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'prayer_times_data.dart';

class ProAzanEngine {
  static const int baseAlarmId = 8000;

  /// ================= INITIALIZE =================
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AndroidAlarmManager.initialize();

    await _requestPermissions();
    await scheduleTodayAzan();
  }

  /// ================= PERMISSIONS =================
  static Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    // Android 13+ Notification Permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Android 12+ Exact Alarm Permission
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Optional but recommended (Battery optimization ignore)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// ================= SCHEDULE ALL PRAYERS =================
  static Future<void> scheduleTodayAzan() async {
    final now = DateTime.now();

    final safeTimes = PrayerTimesData.times.length >= 5
        ? PrayerTimesData.times
        : const [
      TimeOfDay(hour: 5, minute: 0),
      TimeOfDay(hour: 12, minute: 30),
      TimeOfDay(hour: 16, minute: 30),
      TimeOfDay(hour: 18, minute: 30),
      TimeOfDay(hour: 20, minute: 0),
    ];

    for (int i = 0; i < 5; i++) {
      final t = safeTimes[i];

      DateTime prayerTime =
      DateTime(now.year, now.month, now.day, t.hour, t.minute);

      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        prayerTime,
        baseAlarmId + i,
        _azanCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  }

  /// ================= REFRESH AFTER USER CHANGE =================
  static Future<void> refreshAfterChange() async {
    for (int i = 0; i < 5; i++) {
      await AndroidAlarmManager.cancel(baseAlarmId + i);
    }
    await scheduleTodayAzan();
  }

  /// ================= BACKGROUND CALLBACK =================
  @pragma('vm:entry-point')
  static Future<void> _azanCallback() async {
    WidgetsFlutterBinding.ensureInitialized();

    final player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.play(AssetSource('audio/azaan.mp3'));
    } catch (e) {
      debugPrint("Azan error: $e");
    }

    // Reschedule next day automatically
    await scheduleTodayAzan();
  }
}