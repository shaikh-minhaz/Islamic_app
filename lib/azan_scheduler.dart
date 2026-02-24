import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'prayer_times_data.dart';

@pragma('vm:entry-point')
class ProAzanEngine {
  static const int baseAlarmId = 5000;
  static const int midnightAlarmId = 9999;

  /// ================= INIT =================
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AndroidAlarmManager.initialize();
    await _requestPermissions();
  }

  /// ================= PERMISSIONS =================
  static Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    // Android 13+ notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Android 12+ exact alarm permission
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Optional battery optimization ignore
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// ================= PLAY AZAN =================
  @pragma('vm:entry-point')
  static Future<void> playAzan(int id) async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final todayKey =
    DateTime.now().toIso8601String().substring(0, 10);

    final lastPlayedId = prefs.getInt("last_azan_id");
    final lastPlayedDate = prefs.getString("last_azan_date");

    // Duplicate protection (per day)
    if (lastPlayedId == id && lastPlayedDate == todayKey) return;

    await prefs.setInt("last_azan_id", id);
    await prefs.setString("last_azan_date", todayKey);

    final player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.stop);

      // IMPORTANT: No silent bypass
      await player.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransient,
            stayAwake: true,
          ),
        ),
      );

      await player.play(AssetSource('audio/azaan.mp3'));

      // Safety dispose after 2 minutes
      Future.delayed(const Duration(minutes: 2), () async {
        await player.dispose();
      });

    } catch (e) {
      debugPrint("Azan error: $e");
    }
  }

  /// ================= SCHEDULE TODAY =================
  static Future<void> scheduleToday() async {
    final now = DateTime.now();

    if (PrayerTimesData.times.isEmpty) return;

    for (int i = 0; i < PrayerTimesData.times.length; i++) {
      final t = PrayerTimesData.times[i];

      DateTime prayerTime =
      DateTime(now.year, now.month, now.day, t.hour, t.minute);

      // If time passed → schedule for tomorrow
      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        prayerTime,
        baseAlarmId + i,
        playAzan,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  }

  /// ================= MIDNIGHT REFRESH =================
  static Future<void> scheduleMidnightRefresh() async {
    final now = DateTime.now();

    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
      0,
      1,
    );

    await AndroidAlarmManager.oneShotAt(
      nextMidnight,
      midnightAlarmId,
      midnightTask,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  /// ================= MIDNIGHT TASK =================
  @pragma('vm:entry-point')
  static Future<void> midnightTask() async {
    WidgetsFlutterBinding.ensureInitialized();

    await PrayerTimesData.init();
    await scheduleToday();
    await scheduleMidnightRefresh();
  }

  /// ================= MANUAL REFRESH =================
  static Future<void> refreshAfterChange() async {
    for (int i = 0; i < 5; i++) {
      await AndroidAlarmManager.cancel(baseAlarmId + i);
    }

    await AndroidAlarmManager.cancel(midnightAlarmId);

    await scheduleToday();
    await scheduleMidnightRefresh();
  }
}