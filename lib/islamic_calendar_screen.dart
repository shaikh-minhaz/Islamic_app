import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_colors.dart';

class IslamicCalendarScreen extends StatefulWidget {
  const IslamicCalendarScreen({super.key});

  @override
  State<IslamicCalendarScreen> createState() => _IslamicCalendarScreenState();
}

class _IslamicCalendarScreenState extends State<IslamicCalendarScreen> {
  int displayMonth = 1;
  int displayYear = 1447;

  String monthTitle = "Loading...";
  List<Map<String, dynamic>> monthDays = [];

  String? selectedFestivalReason;
  String? nextFestivalText;

  @override
  void initState() {
    super.initState();
    _start();
  }

  ////////////////////////////////////////////////////////////
  /// 🔥 START FLOW
  ////////////////////////////////////////////////////////////

  Future<void> _start() async {
    await _loadFromCache(); // offline first
    await _initCurrentHijriMonth(); // FIXED current Hijri month
    await _loadHijriCalendar(); // online fetch

    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _loadHijriCalendar();
      }
    });
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 GET CURRENT HIJRI MONTH/YEAR  (BUG FIX)
  ////////////////////////////////////////////////////////////

  Future<void> _initCurrentHijriMonth() async {
    try {
      final now = DateTime.now();

      final url = Uri.parse(
        "https://api.aladhan.com/v1/gToH?date=${now.day}-${now.month}-${now.year}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      final hijri = data["data"]["hijri"];

      displayMonth = int.parse(hijri["month"]["number"]);
      displayYear = int.parse(hijri["year"]);
    } catch (_) {}
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 LOAD FROM CACHE
  ////////////////////////////////////////////////////////////

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedTitle = prefs.getString("hijri_title");
    final cachedDays = prefs.getString("hijri_days");
    final cachedNext = prefs.getString("hijri_next");

    if (cachedTitle != null && cachedDays != null) {
      monthTitle = cachedTitle;
      nextFestivalText = cachedNext;

      final List decoded = json.decode(cachedDays);
      monthDays = decoded.cast<Map<String, dynamic>>();

      setState(() {});
    }
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 SAVE CACHE
  ////////////////////////////////////////////////////////////

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("hijri_title", monthTitle);
    await prefs.setString("hijri_days", json.encode(monthDays));
    await prefs.setString("hijri_next", nextFestivalText ?? "");
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 FETCH HIJRI CALENDAR FROM API
  ////////////////////////////////////////////////////////////

  Future<void> _loadHijriCalendar() async {
    try {
      final now = DateTime.now();

      final url = Uri.parse(
        "https://api.aladhan.com/v1/hijriCalendar/$displayMonth/$displayYear",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      final List list = data["data"] ?? [];
      if (list.isEmpty) return;

      final firstHijri = list.first["hijri"];

      monthTitle =
          "${firstHijri?["month"]?["en"] ?? "Hijri"} ${firstHijri?["year"] ?? ""}";

      nextFestivalText = null;

      monthDays = list.map<Map<String, dynamic>>((d) {
        final hijri = d["hijri"];
        final gregorian = d["gregorian"];

        final int day = int.tryParse(hijri?["day"] ?? "0") ?? 0;
        final int gregorianDay = int.tryParse(gregorian?["day"] ?? "0") ?? 0;

        final int weekday =
            int.tryParse(gregorian?["weekday"]?["number"] ?? "1") ?? 1;

        final List holidays = hijri?["holidays"] ?? [];

        /// next upcoming festival
        if (nextFestivalText == null &&
            holidays.isNotEmpty &&
            (displayYear > now.year ||
                (displayYear == now.year && gregorianDay >= now.day))) {
          nextFestivalText =
              "Next festival: ${holidays.first} on $day ${hijri?["month"]?["en"]}";
        }

        return {
          "day": day,
          "weekday": weekday,
          "holiday": holidays.isNotEmpty,
          "holidayName": holidays.isNotEmpty ? holidays.first : null,
          "isPast": displayYear < now.year ||
              (displayYear == now.year && gregorianDay < now.day),
          "isToday": displayYear == now.year && gregorianDay == now.day,
        };
      }).toList();

      await _saveToCache();
      setState(() {});
    } catch (_) {}
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 MONTH NAVIGATION
  ////////////////////////////////////////////////////////////

  void _nextMonth() {
    if (displayMonth == 12) {
      displayMonth = 1;
      displayYear++;
    } else {
      displayMonth++;
    }
    _loadHijriCalendar();
  }

  void _prevMonth() {
    if (displayMonth == 1) {
      displayMonth = 12;
      displayYear--;
    } else {
      displayMonth--;
    }
    _loadHijriCalendar();
  }

  ////////////////////////////////////////////////////////////
  /// 🔹 UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    List<Map<String, dynamic>> calendarDays = [];

    if (monthDays.isNotEmpty) {
      int firstWeekday = monthDays.first["weekday"] ?? 1;

      for (int i = 1; i < firstWeekday; i++) {
        calendarDays.add({"empty": true});
      }

      calendarDays.addAll(monthDays);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text("Islamic Calendar"),
        backgroundColor: primaryBrown,
        centerTitle: true,
      ),
      body: monthDays.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                /// Month title
                Container(
                  width: double.infinity,
                  color: Colors.green.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _prevMonth,
                      ),
                      Text(
                        monthTitle,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                /// Calendar grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: calendarDays.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) {
                      final item = calendarDays[i];
                      if (item["empty"] == true) return const SizedBox();

                      final day = item["day"];
                      final isHoliday = item["holiday"];
                      final isPast = item["isPast"];
                      final isToday = item["isToday"];
                      final holidayName = item["holidayName"];

                      Color bg = Colors.white;

                      if (isHoliday && isPast)
                        bg = Colors.green.withOpacity(0.15);
                      else if (isHoliday)
                        bg = Colors.green.withOpacity(0.35);
                      else if (isPast) bg = Colors.grey.shade300;

                      if (isToday) bg = primaryBrown;

                      return GestureDetector(
                        onTap: () => setState(
                            () => selectedFestivalReason = holidayName),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.045,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? Colors.white
                                  : Colors.green.shade900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (selectedFestivalReason != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      selectedFestivalReason!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),

                if (nextFestivalText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      nextFestivalText!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: primaryBrown,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// 🔹 TODAY HIJRI FOR HOME SCREEN (ONLINE + OFFLINE)
//////////////////////////////////////////////////////////////

Future<String> fetchTodayHijriForHome() async {
  final prefs = await SharedPreferences.getInstance();

  try {
    final now = DateTime.now();

    final url = Uri.parse(
      "https://api.aladhan.com/v1/gToH?date=${now.day}-${now.month}-${now.year}",
    );

    final res = await http.get(url).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final h = data["data"]?["hijri"];

      final todayHijri =
          "${h?["day"] ?? ""} ${h?["month"]?["en"] ?? ""} ${h?["year"] ?? ""} AH";

      await prefs.setString("today_hijri", todayHijri);
      return todayHijri;
    }
  } catch (_) {}

  return prefs.getString("today_hijri") ?? "Hijri date unavailable";
}
