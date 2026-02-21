import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_data.dart';

@pragma('vm:entry-point')
class ProAzanEngine {
  static const int baseAlarmId = 5000;
  static const int midnightAlarmId = 9999;

  /// 🔥 Initialize Alarm Manager
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();
  }

  /// 🔥 Runs even when app is terminated
  @pragma('vm:entry-point')
  static Future<void> _playAzan(int id) async {
    final prefs = await SharedPreferences.getInstance();

    // Strong duplicate protection
    final lastPlayedId = prefs.getInt("last_azan_id");
    final lastPlayedDate = prefs.getString("last_azan_date");

    final todayKey = DateTime.now().toIso8601String().substring(0, 10);

    if (lastPlayedId == id && lastPlayedDate == todayKey) return;

    await prefs.setInt("last_azan_id", id);
    await prefs.setString("last_azan_date", todayKey);

    final player = AudioPlayer();
    await player.play(AssetSource('audio/azaan.mp3'));
  }

  /// 🔥 Schedule today's prayers
  static Future<void> scheduleToday() async {
    final now = DateTime.now();

    if (PrayerTimesData.times.isEmpty) return;

    for (int i = 0; i < PrayerTimesData.times.length; i++) {
      final t = PrayerTimesData.times[i];

      final prayerTime =
          DateTime(now.year, now.month, now.day, t.hour, t.minute);

      if (prayerTime.isAfter(now)) {
        await AndroidAlarmManager.oneShotAt(
          prayerTime,
          baseAlarmId + i,
          _playAzan,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }
    }
  }

  /// 🔥 Schedule midnight refresh (12:01 AM)
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
      _midnightTask,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  /// 🔥 Midnight Task
  @pragma('vm:entry-point')
  static Future<void> _midnightTask() async {
    await PrayerTimesData.init(); // Reload API/custom times
    await scheduleToday(); // Schedule new day
    await scheduleMidnightRefresh(); // Schedule next midnight
  }

  /// 🔥 Refresh when user changes time
  static Future<void> refreshAfterChange() async {
    // Cancel existing prayer alarms
    for (int i = 0; i < 5; i++) {
      await AndroidAlarmManager.cancel(baseAlarmId + i);
    }

    // Cancel midnight refresh alarm
    await AndroidAlarmManager.cancel(midnightAlarmId);

    // Reschedule fresh alarms
    await scheduleToday();
    await scheduleMidnightRefresh();
  }
}
