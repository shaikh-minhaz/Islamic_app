import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'prayer_times_data.dart';

Future<void> initializeBackgroundAzan() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: "azan_channel",
      initialNotificationTitle: "Hidayah",
      initialNotificationContent: "Background Azaan Active",
      foregroundServiceNotificationId: 999,
    ),
    iosConfiguration: IosConfiguration(),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final player = AudioPlayer();
  String? lastPlayed;

  Timer.periodic(const Duration(seconds: 1), (_) async {
    final now = DateTime.now();

    /// 🔥 Safe fallback (same logic as HomeScreen)
    final safeTimes = PrayerTimesData.times.length >= 5
        ? PrayerTimesData.times
        : const [
            TimeOfDay(hour: 5, minute: 0),
            TimeOfDay(hour: 12, minute: 30),
            TimeOfDay(hour: 16, minute: 30),
            TimeOfDay(hour: 18, minute: 30),
            TimeOfDay(hour: 20, minute: 0),
          ];

    final names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

    for (int i = 0; i < 5; i++) {
      final t = safeTimes[i];

      final prayerTime =
          DateTime(now.year, now.month, now.day, t.hour, t.minute);

      final diff = now.difference(prayerTime).inSeconds;

      if (diff >= 0 && diff <= 2 && lastPlayed != names[i]) {
        lastPlayed = names[i];

        try {
          await player.play(AssetSource('audio/azaan.mp3'));
        } catch (_) {}
      }
    }
  });
}
