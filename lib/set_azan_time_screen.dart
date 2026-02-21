import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'prayer_times_data.dart';
import 'app_colors.dart';
import 'azan_scheduler.dart';

class SetAzanTimeScreen extends StatefulWidget {
  const SetAzanTimeScreen({super.key});

  @override
  State<SetAzanTimeScreen> createState() => _SetAzanTimeScreenState();
}

class _SetAzanTimeScreenState extends State<SetAzanTimeScreen>
    with SingleTickerProviderStateMixin {
  late List<TimeOfDay> _times;
  late AnimationController _controller;

  final List<String> _names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

  final List<IconData> _icons = [
    Icons.dark_mode,
    Icons.wb_sunny,
    Icons.cloud,
    Icons.nights_stay,
    Icons.bedtime,
  ];

  @override
  void initState() {
    super.initState();
    _times = List.from(PrayerTimesData.times);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );

    if (picked != null) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _saveTimes() async {
    await PrayerTimesData.saveUserTimes(_times);
    await ProAzanEngine.refreshAfterChange();

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _resetTimes() async {
    await PrayerTimesData.resetToAPI();
    await ProAzanEngine.refreshAfterChange();

    setState(() {
      _times = List.from(PrayerTimesData.times);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          /// 🔥 Animated Islamic Gradient Background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + _controller.value * 2, -1),
                    end: Alignment(1 - _controller.value * 2, 1),
                    colors: [
                      primaryBrown,
                      primaryBrown.withOpacity(0.8),
                      Colors.brown.shade200,
                    ],
                  ),
                ),
              );
            },
          ),

          /// 🌙 Floating Moon Icon Animation
          Positioned(
            top: height * 0.15,
            left: width * 0.1,
            child: Icon(
              Icons.nightlight_round,
              size: 80,
              color: Colors.white.withOpacity(0.1),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .moveY(begin: -10, end: 10, duration: 4.seconds)
                .fade(duration: 2.seconds),
          ),

          /// 🌟 Main Card
          Center(
            child: SingleChildScrollView(
              child: Card(
                color: backgroundLight,
                elevation: 15,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                margin: EdgeInsets.symmetric(horizontal: width * 0.06),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.05,
                    vertical: height * 0.03,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Set Azan Time',
                        style: TextStyle(fontSize: 20),
                      ),

                      /// Prayer List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _names.length,
                        itemBuilder: (_, i) {
                          return Container(
                            margin: EdgeInsets.only(bottom: height * 0.02),
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.04,
                              vertical: height * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundDark,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _icons[i],
                                      color: primaryBrown,
                                      size: width * 0.07,
                                    ),
                                    SizedBox(width: width * 0.04),
                                    Text(
                                      _names[i],
                                      style: TextStyle(
                                        fontSize: width * 0.045,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBrown,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _pickTime(i),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: width * 0.04,
                                      vertical: height * 0.01,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryBrown.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _times[i].format(context),
                                      style: TextStyle(
                                        fontSize: width * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: primaryBrown,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      SizedBox(height: height * 0.02),

                      /// Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryBrown),
                                padding: EdgeInsets.symmetric(
                                  vertical: height * 0.02,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _resetTimes,
                              child: Text(
                                "Reset",
                                style: TextStyle(
                                  color: primaryBrown,
                                  fontSize: width * 0.04,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.04),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBrown,
                                padding: EdgeInsets.symmetric(
                                  vertical: height * 0.02,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _saveTimes,
                              child: Text(
                                "Save",
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
