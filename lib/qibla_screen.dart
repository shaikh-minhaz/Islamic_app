import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'app_colors.dart'; // Make sure this file exists with your color variables

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _heading;
  double? _qiblaDirection;
  String? _error;
  bool _hasVibrated = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initQibla();
  }

  // Is function ko refresh button ke liye bhi use karenge
  Future<void> _initQibla() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await _checkPermissionAndCalculate();
    } catch (e) {
      setState(() => _error = "Unable to get location. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissionAndCalculate() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _error = "Your Location are Off\nPlease turn On Your Location\nClick the Button.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _error = "Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _error = "Location permissions are permanently denied.\nPlease enable from settings.");
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    /// Kaaba coordinates
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;

    final lat1 = pos.latitude * pi / 180;
    final lng1 = pos.longitude * pi / 180;
    final lat2 = kaabaLat * pi / 180;
    final lng2 = kaabaLng * pi / 180;

    final dLng = lng2 - lng1;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    final bearing = atan2(y, x);

    setState(() {
      _qiblaDirection = (bearing * 180 / pi + 360) % 360;
      _error = null; // Clear error on success
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text("Qibla Direction"),
        backgroundColor: backgroundLight,
        foregroundColor: primaryBrown,
        elevation: 0,
        actions: [
          // Toolbar par refresh button taake kabhi bhi refresh kiya ja sake
          IconButton(
            onPressed: _initQibla,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorUI()
          : _qiblaDirection == null
          ? const Center(child: Text("Calculating Qibla..."))
          : StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: Text("Compass not available"));
          }

          _heading = snap.data!.heading;

          if (_heading == null) {
            return const Center(child: Text("Device sensors not responding"));
          }

          double normalizedHeading = (_heading! % 360 + 360) % 360;
          double diff = (normalizedHeading - _qiblaDirection!).abs();
          if (diff > 180) diff = 360 - diff;

          final facing = diff <= 3;

          if (facing && !_hasVibrated) {
            _hasVibrated = true;
            Vibration.vibrate(duration: 300);
          }
          if (!facing) _hasVibrated = false;

          return _buildCompass(facing, normalizedHeading);
        },
      ),
    );
  }

  // Error screen with Refresh Button
  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _initQibla,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again / Refresh"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompass(bool facing, double heading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -(heading * pi / 180),
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _CompassPainter(qiblaDirection: _qiblaDirection!),
                ),
              ),
              Icon(
                Icons.navigation,
                size: 60,
                color: facing ? Colors.green : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            facing ? "✔ You are facing Qibla 🕋" : "Turn phone to align with 🕋",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: facing ? Colors.green : textDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Phone: ${heading.toStringAsFixed(0)}° | Qibla: ${_qiblaDirection!.toStringAsFixed(0)}°",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double qiblaDirection;
  _CompassPainter({required this.qiblaDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, circlePaint);

    final tickPaint = Paint()..color = Colors.black..strokeWidth = 2;

    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 7.0;
      final angle = (i - 90) * pi / 180;

      final p1 = Offset(center.dx + (radius - tickLength) * cos(angle), center.dy + (radius - tickLength) * sin(angle));
      final p2 = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }

    void drawLabel(String text, double degrees, Color color) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final angle = (degrees - 90) * pi / 180;
      final offset = Offset(
        center.dx + (radius - 40) * cos(angle) - textPainter.width / 2,
        center.dy + (radius - 40) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    drawLabel("N", 0, Colors.red);
    drawLabel("E", 90, Colors.black);
    drawLabel("S", 180, Colors.black);
    drawLabel("W", 270, Colors.black);

    final qiblaAngle = (qiblaDirection - 90) * pi / 180;
    final kaabaMarker = TextPainter(
      text: const TextSpan(text: "🕋", style: TextStyle(fontSize: 26)),
      textDirection: TextDirection.ltr,
    );
    kaabaMarker.layout();

    final kaabaOffset = Offset(
      center.dx + (radius - 42) * cos(qiblaAngle) - kaabaMarker.width / 2,
      center.dy + (radius - 42) * sin(qiblaAngle) - kaabaMarker.height / 2,
    );
    kaabaMarker.paint(canvas, kaabaOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}