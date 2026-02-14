// Updated HomeScreen with extra "Set Azaan" tile added
// Only UI change — rest of logic same

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'qibla_screen.dart';
import 'duas_screen.dart';
import 'prayer_times_data.dart';
import 'set_azan_time_screen.dart';
import 'islamic_calendar_screen.dart';
import 'profile_screen.dart';

//////////////////////////////////////////////////////////////
class Prayer {
  final String name;
  final TimeOfDay time;

  Prayer(this.name, this.time);
}
//////////////////////////////////////////////////////////////

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final AudioPlayer _player = AudioPlayer();
  Timer? _azanTimer;
  String? _lastPlayedPrayer;

  List<Widget> get _pages => [
        _HomeContent(),
        const QiblaScreen(),
        const DuasScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _startAzanChecker();
  }

  void _startAzanChecker() {
    _azanTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();
      final names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

      for (int i = 0; i < names.length; i++) {
        final t = PrayerTimesData.times[i];

        final prayerTime =
            DateTime(now.year, now.month, now.day, t.hour, t.minute);

        final diff = now.difference(prayerTime).inSeconds;

        if (diff >= 0 && diff <= 2 && _lastPlayedPrayer != names[i]) {
          _lastPlayedPrayer = names[i];

          try {
            await _player.play(AssetSource('audio/azaan.mp3'));
          } catch (_) {
            await _player.play(AssetSource('audio/beep.mp3'));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _azanTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: primaryBrown,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 3) return _showMoreMenu();
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Qibla"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Duas"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// HOME CONTENT
//////////////////////////////////////////////////////////////

class _HomeContent extends StatefulWidget {
  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  late Timer _timer;
  String arabicDate = "Loading...";

  bool isAzanPhase = false;
  bool isJamatPhase = false;

  int remainingSeconds = 0;
  int currentPrayerIndex = 0;

  String userName = "User";

  Future<void> _loadHijri() async {
    arabicDate = await fetchTodayHijriForHome();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadUserName();
    _loadHijri(); // 👈 add this
  }

  void _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("user_name") ?? "User";
    });
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();
      bool foundPhase = false;

      for (int i = 0; i < PrayerTimesData.times.length; i++) {
        final t = PrayerTimesData.times[i];

        final azan = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        final jamat = azan.add(const Duration(minutes: 10));
        final jamatEnd = jamat.add(const Duration(minutes: 1));

        if (now.isAfter(azan) && now.isBefore(jamat)) {
          isAzanPhase = true;
          isJamatPhase = false;
          currentPrayerIndex = i;
          remainingSeconds = jamat.difference(now).inSeconds;
          foundPhase = true;
          break;
        }

        if (now.isAfter(jamat) && now.isBefore(jamatEnd)) {
          if (!isJamatPhase) {
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 300]);
            }
          }

          isAzanPhase = false;
          isJamatPhase = true;
          currentPrayerIndex = i;
          foundPhase = true;
          break;
        }
      }

      if (!foundPhase) {
        if (isJamatPhase) Vibration.cancel();
        isAzanPhase = false;
        isJamatPhase = false;
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    Vibration.cancel();
    super.dispose();
  }

  Prayer getNextPrayer(List<Prayer> prayers) {
    final now = DateTime.now();

    for (var p in prayers) {
      final dt =
          DateTime(now.year, now.month, now.day, p.time.hour, p.time.minute);
      if (dt.isAfter(now)) return p;
    }
    return prayers.first;
  }

  String formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    final prayers = List.generate(
        names.length, (i) => Prayer(names[i], PrayerTimesData.times[i]));

    final nextPrayer = getNextPrayer(prayers);
    final displayPrayer = (isAzanPhase || isJamatPhase)
        ? prayers[currentPrayerIndex]
        : nextPrayer;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: height * 0.02),
            Text(
              "Assalamualaikum $userName",
              style: GoogleFonts.poppins(
                fontSize: width * 0.055,
                fontWeight: FontWeight.w600,
                color: primaryBrown,
              ),
            ),
            SizedBox(height: height * 0.01),
            Text(
              "Prayer Times",
              style: GoogleFonts.poppins(
                fontSize: width * 0.08,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            SizedBox(height: height * 0.02),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IslamicCalendarScreen(),
                  ),
                );
              },
              child: _ArabicDateCard(width, height, arabicDate),
            ),
            _NextPrayerFullCard(
              width: width,
              isAzan: isAzanPhase,
              isJamat: isJamatPhase,
              prayer: displayPrayer,
              remaining: formatCountdown(remainingSeconds),
              context: context,
            ),
            SizedBox(height: height * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.05),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prayers.length + 1, // extra tile
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                  if (i < prayers.length) {
                    return _PrayerTile(prayers[i], width, context);
                  } else {
                    return _SetAzanTile(width, context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// EXTRA TILE → SET AZAAN
//////////////////////////////////////////////////////////////

class _SetAzanTile extends StatelessWidget {
  final double width;
  final BuildContext contextRef;

  const _SetAzanTile(this.width, this.contextRef);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SetAzanTimeScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: primaryBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.access_time, color: Colors.brown),
              SizedBox(height: 6),
              Text("Set Azaan"),
            ],
          ),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// PRAYER TILE
//////////////////////////////////////////////////////////////

class _PrayerTile extends StatelessWidget {
  final Prayer prayer;
  final double width;
  final BuildContext contextRef;

  const _PrayerTile(this.prayer, this.width, this.contextRef);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prayer.name),
            Text(prayer.time.format(contextRef)),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// UI WIDGETS
//////////////////////////////////////////////////////////////

class _ArabicDateCard extends StatelessWidget {
  final double width;
  final double height;
  final String date;

  const _ArabicDateCard(this.width, this.height, this.date);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width * 0.9,
      padding: EdgeInsets.all(width * 0.05),
      margin: EdgeInsets.only(bottom: height * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, color: primaryBrown, size: width * 0.12),
          SizedBox(width: width * 0.04),
          Text(date, style: GoogleFonts.poppins(fontSize: width * 0.05)),
        ],
      ),
    );
  }
}

class _NextPrayerFullCard extends StatelessWidget {
  final double width;
  final bool isAzan;
  final bool isJamat;
  final Prayer prayer;
  final String remaining;
  final BuildContext context;

  const _NextPrayerFullCard({
    required this.width,
    required this.isAzan,
    required this.isJamat,
    required this.prayer,
    required this.remaining,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    Color color = isJamat
        ? Colors.green
        : isAzan
            ? Colors.orange
            : primaryBrown;

    return Container(
      width: width * 0.9,
      padding: EdgeInsets.all(width * 0.05),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.mosque, size: width * 0.12, color: color),
          SizedBox(width: width * 0.04),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isJamat
                  ? "Jamat Time"
                  : isAzan
                      ? "Jamat Countdown"
                      : "Next Prayer"),
              Text(
                isAzan ? remaining : prayer.name,
                style: GoogleFonts.poppins(
                    fontSize: width * 0.075,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              if (!isAzan && !isJamat) Text(prayer.time.format(this.context)),
            ],
          ),
        ],
      ),
    );
  }
}
