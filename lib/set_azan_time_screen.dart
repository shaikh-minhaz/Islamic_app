import 'package:flutter/material.dart';
import 'prayer_times_data.dart';

class SetAzanTimeScreen extends StatefulWidget {
  const SetAzanTimeScreen({super.key});

  @override
  State<SetAzanTimeScreen> createState() => _SetAzanTimeScreenState();
}

class _SetAzanTimeScreenState extends State<SetAzanTimeScreen> {
  late List<TimeOfDay> _times;

  final List<String> _names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

  @override
  void initState() {
    super.initState();
    _times = List.from(PrayerTimesData.times);
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

  void _saveTimes() {
    PrayerTimesData.times = _times;
    Navigator.pop(context, true); // 🔥 home refresh signal
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Azaan Time")),
      body: ListView.builder(
        itemCount: _names.length,
        itemBuilder: (_, i) {
          return ListTile(
            title: Text(_names[i]),
            trailing: Text(_times[i].format(context)),
            onTap: () => _pickTime(i),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveTimes,
          child: const Text("Save"),
        ),
      ),
    );
  }
}
