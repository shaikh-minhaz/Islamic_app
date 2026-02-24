import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
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

  List<TimeOfDay> _times = [];
  late AnimationController _controller;
  bool _locationOff = false;

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _initializeData();
    _checkLocation();
  }

  Future<void> _initializeData() async {
    await PrayerTimesData.init();
    if (!mounted) return;

    setState(() {
      _times = List.from(PrayerTimesData.times);
    });
  }

  Future<void> _checkLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return;

    setState(() {
      _locationOff = !serviceEnabled;
    });
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _refreshAfterLocationOn() async {
    await PrayerTimesData.init(); // fetch again
    await ProAzanEngine.refreshAfterChange();
    await _checkLocation();

    if (!mounted) return;

    setState(() {
      _times = List.from(PrayerTimesData.times);
    });
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

    if (_locationOff) {
      _showLocationDialog();
      return;
    }

    await PrayerTimesData.saveUserTimes(_times);
    await ProAzanEngine.refreshAfterChange();

    if (mounted) Navigator.pop(context, true);
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Location Required"),
        content: const Text(
            "Please enable Location to calculate accurate prayer times."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openLocationSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (_times.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [

          /// Animated Background
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

                      const SizedBox(height: 20),

                      /// LOCATION WARNING + REFRESH
                      if (_locationOff) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Location is OFF",
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _refreshAfterLocationOn,
                                child: const Text("Refresh After Enabling"),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _names.length,
                        itemBuilder: (_, i) {

                          final safeTime = _times[i];

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
                                  child: Text(
                                    safeTime.format(context),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryBrown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await PrayerTimesData.resetToAPI();
                                await ProAzanEngine.refreshAfterChange();
                                _initializeData();
                              },
                              child: const Text("Reset"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveTimes,
                              child: const Text("Save"),
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