import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'app_colors.dart';

class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key});

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _saveUsername() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _controller.text.trim());

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final titleSize = width * 0.08;
    final fieldHeight = height * 0.07;
    final buttonHeight = height * 0.065;
    final horizontalPadding = width * 0.08;

    return Scaffold(
      body: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundLight, backgroundDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// 🌙 APP TITLE
                      Text(
                        "Welcome to Hidayah",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: primaryBrown,
                        ),
                      ),

                      SizedBox(height: height * 0.015),

                      Text(
                        "Enter your name to continue",
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.04,
                          color: textDark,
                        ),
                      ),

                      SizedBox(height: height * 0.05),

                      /// ✏️ USERNAME FIELD
                      Container(
                        height: fieldHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(width * 0.04),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: width * 0.03,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: TextFormField(
                          controller: _controller,
                          maxLength: 30,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "Your Name",
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: width * 0.05,
                              vertical: height * 0.02,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Name is required";
                            }
                            if (!RegExp(r'^[a-zA-Z ]+$')
                                .hasMatch(value.trim())) {
                              return "Only letters allowed";
                            }
                            return null;
                          },
                        ),
                      ),

                      SizedBox(height: height * 0.05),

                      /// 🚀 CONTINUE BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBrown,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(width * 0.04),
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    _saveUsername();
                                  }
                                },
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  "Continue",
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.045,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
