import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'prayer_times_data.dart';
import 'azan_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 VERY IMPORTANT (Load saved manual times first)
  await PrayerTimesData.init();

  // Initialize alarm engine
  await ProAzanEngine.init();

  // Schedule alarms after data load
  await ProAzanEngine.scheduleToday();
  await ProAzanEngine.scheduleMidnightRefresh();

  // Portrait mode lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hidayah - Path of Guidance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B6F47),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F2EE),
      ),
      home: const SplashScreen(),
    );
  }
}