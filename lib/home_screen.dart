// ✅ Fully Responsive Updated HomeScreen
// Username fixed + adaptive grid + better scaling

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:table_calendar/table_calendar.dart';
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
    const ProfileScreen(),
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
        child: ListTile(
          leading: const Icon(Icons.person),
          title: const Text("Profile"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
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
          if (i == 4) return _showMoreMenu();
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

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadUserName();
    _loadHijri();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("username") ?? "User";
    });
  }

  Future<void> _loadHijri() async {
    arabicDate = await fetchTodayHijriForHome();
    setState(() {});
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
              Vibration.vibrate(pattern: [0, 300, 200, 300]);
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
    final prayers =
    List.generate(names.length, (i) => Prayer(names[i], PrayerTimesData.times[i]));

    final nextPrayer = getNextPrayer(prayers);
    final displayPrayer =
    (isAzanPhase || isJamatPhase) ? prayers[currentPrayerIndex] : nextPrayer;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: height * 0.01),

            /// 👋 Welcome Text Responsive
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.05),
              child: Column(
                children: [
                  Text(
                    "Assalamualaikum",
                    style: GoogleFonts.poppins(
                      fontSize: width * 0.06,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    userName,
                    style: GoogleFonts.poppins(
                      fontSize: width * 0.060,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: primaryBrown,thickness: 1.5,),
            Text(
              "Prayer Times",
              style: GoogleFonts.poppins(
                fontSize: width * 0.09,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            SizedBox(height: height * 0.03),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount =
                  constraints.maxWidth > 600 ? 4 : 3;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prayers.length + 1,
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: width * 0.03,
                      mainAxisSpacing: width * 0.03,
                    ),
                    itemBuilder: (_, i) {
                      if (i < prayers.length) {
                        return _PrayerTile(prayers[i], width, context);
                      } else {
                        return _SetAzanTile(width, context);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: width * 0.9,
              child: _IslamicCalendarButton(width: width),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslamicCalendarButton extends StatelessWidget {
  final double width;

  const _IslamicCalendarButton({required this.width});

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    final todayHijri =
        "${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FastIslamicCalendar(),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(width * 0.05),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryBrown,
              primaryBrown.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(width * 0.05),
          boxShadow: [
            BoxShadow(
              color: primaryBrown.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_month,
                color: Colors.white, size: width * 0.08),
            SizedBox(height: width * 0.02),
            Text(
              todayHijri,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: width * 0.045,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: width * 0.01),
            Text(
              "Tap to open Islamic Calendar",
              style: GoogleFonts.poppins(
                fontSize: width * 0.03,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////////////////

class _SetAzanTile extends StatelessWidget {
  final double width;
  final BuildContext contextRef;

  const _SetAzanTile(this.width, this.contextRef);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SetAzanTimeScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: primaryBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(width * 0.04),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time,
                  color: primaryBrown, size: width * 0.08),
              SizedBox(height: width * 0.02),
              Text("Set Azaan",
                  style: GoogleFonts.poppins(fontSize: width * 0.035)),
            ],
          ),
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(width * 0.04),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prayer.name,
                style: GoogleFonts.poppins(
                    fontSize: width * 0.035)),
            SizedBox(height: width * 0.015),
            Text(prayer.time.format(contextRef),
                style: GoogleFonts.poppins(
                    fontSize: width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown)),
          ],
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(width * 0.05),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month,
              color: primaryBrown, size: width * 0.1),
          SizedBox(width: width * 0.04),
          Expanded(
            child: Text(
              date,
              style:
              GoogleFonts.poppins(fontSize: width * 0.045),
            ),
          ),
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
        borderRadius: BorderRadius.circular(width * 0.05),
      ),
      child: Row(
        children: [
          Icon(Icons.mosque,
              size: width * 0.1, color: color),
          SizedBox(width: width * 0.04),
          Expanded(
            child: Column(
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
                      fontSize: width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                if (!isAzan && !isJamat)
                  Text(prayer.time.format(this.context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class FastIslamicCalendar extends StatefulWidget {
  const FastIslamicCalendar({super.key});

  @override
  State<FastIslamicCalendar> createState() =>
      _FastIslamicCalendarState();
}

class _FastIslamicCalendarState
    extends State<FastIslamicCalendar> {

  final DateTime _firstDay = DateTime(2000);
  final DateTime _lastDay = DateTime(2100);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  int tasbeehCount = 0;

  /// 🌙 Festival Logic
  String? _getFestival(HijriCalendar h) {
    if (h.hMonth == 9) {
      if (h.hDay == 1) return "🌙 Start of Ramadan";
      return "🌙 Ramadan";
    }

    if (h.hMonth == 10 && h.hDay == 1) {
      return "🎉 Eid ul-Fitr";
    }

    if (h.hMonth == 12 && h.hDay == 10) {
      return "🕌 Eid ul-Adha";
    }

    if (h.hMonth == 1 && h.hDay == 1) {
      return "✨ Islamic New Year";
    }

    if (h.hMonth == 1 && h.hDay == 10) {
      return "⭐ Ashura";
    }

    if (h.hMonth == 3 && h.hDay == 12) {
      return "🌟 Milad un-Nabi";
    }

    return null;
  }

  bool _isRamadan(HijriCalendar h) {
    return h.hMonth == 9;
  }

  bool _isAshura(HijriCalendar h) {
    return h.hMonth == 1 && h.hDay == 10;
  }

  String _getHijriDay(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return "${h.hDay}";
  }

  String _getFullHijri(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return "${h.hDay} ${h.longMonthName} ${h.hYear} AH";
  }

  @override
  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width;
    final selectedHijri =
    HijriCalendar.fromDate(_selectedDay ?? DateTime.now());
    final festival = _getFestival(selectedHijri);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          const SizedBox(height: 40),
          /// 💎 Luxury Selected Date Card
          Container(
            width: width * 0.9,
            padding: EdgeInsets.all(width * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Selected Hijri Date",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  _getFullHijri(_selectedDay ?? DateTime.now()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                if (festival != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      festival,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 15),

          /// 📅 Calendar
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TableCalendar(
                  firstDay: _firstDay,
                  lastDay: _lastDay,
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay, day),

                  onDaySelected:
                      (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },

                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),

                  calendarBuilders:
                  CalendarBuilders(
                    defaultBuilder:
                        (context, date, _) {
                      final h =
                      HijriCalendar.fromDate(date);

                      final isFriday =
                          date.weekday == 5;
                      final isRamadan =
                      _isRamadan(h);
                      final isAshura =
                      _isAshura(h);
                      final fest =
                      _getFestival(h);

                      Color hijriColor =
                          Colors.grey;

                      if (isRamadan)
                        hijriColor = Colors.green;
                      if (isFriday)
                        hijriColor = Colors.blue;
                      if (isAshura)
                        hijriColor = Colors.red;

                      return Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Text(
                            "${date.day}",
                            style: TextStyle(
                              fontWeight: isFriday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            _getHijriDay(date),
                            style: TextStyle(
                              fontSize: 10,
                              color: hijriColor,
                              fontWeight: fest != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (fest != null)
                            const Icon(
                              Icons.star,
                              size: 10,
                              color: Colors.green,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 120),
          ],
      ),
    );
  }
}
