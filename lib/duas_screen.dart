import 'package:flutter/material.dart';
import 'app_colors.dart';

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text("Duas"),
        backgroundColor: backgroundLight,
        foregroundColor: primaryBrown,
        elevation: 0,
      ),
      body: const Center(
        child: Text("Duas Page Coming Soon"),
      ),
    );
  }
}
