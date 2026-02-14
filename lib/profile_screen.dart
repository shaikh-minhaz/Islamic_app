import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();

  String fullName = "";

  @override
  void initState() {
    super.initState();
    _loadProfile(); // 👈 saved name load
  }

  /// 🔹 Load saved name
  void _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("user_name");

    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        fullName = savedName;

        /// split karke fields me bhi dikhayega
        final parts = savedName.split(" ");
        _nameController.text = parts.first;
        if (parts.length > 1) {
          _surnameController.text = parts.sublist(1).join(" ");
        }
      });
    }
  }

  /// 🔹 Save profile permanently
  void _saveProfile() async {
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();

    if (name.isEmpty || surname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter name and surname")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_name", "$name $surname");

    setState(() {
      fullName = "$name $surname";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile saved successfully")),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: primaryBrown,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 👤 Display Saved Name
            if (fullName.isNotEmpty)
              Center(
                child: Text(
                  fullName,
                  style: GoogleFonts.poppins(
                    fontSize: width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
              ),

            const SizedBox(height: 30),

            /// 📝 Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "First Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// 📝 Surname Field
            TextField(
              controller: _surnameController,
              decoration: const InputDecoration(
                labelText: "Surname",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            /// 💾 Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "Save Profile",
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
