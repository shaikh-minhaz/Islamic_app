import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'app_colors.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _heading; // phone direction 0–360
  double? _qiblaDirection; // real qibla bearing
  String? _error;
  bool _hasVibrated = false; // prevent continuous vibration

  @override
  void initState() {
    super.initState();
    _initQibla();
  }

  Future<void> _initQibla() async {
    try {
      await _checkPermissionAndCalculate();
    } catch (_) {
      setState(() => _error = "Unable to get location");
    }
  }

  Future<void> _checkPermissionAndCalculate() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _error = "Location service OFF");
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
      setState(() => _error = "Permission permanently denied");
      return;
    }

    final pos = await Geolocator.getCurrentPosition();

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
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _qiblaDirection == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<CompassEvent>(
                  stream: FlutterCompass.events,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: Text("Compass not available"));
                    }

                    _heading = snap.data!.heading;

                    if (_heading == null) {
                      return const Center(
                          child: Text("Compass reading unavailable"));
                    }

                    /// normalize heading
                    double normalizedHeading = (_heading! % 360 + 360) % 360;

                    /// difference from REAL qibla
                    double diff = (normalizedHeading - _qiblaDirection!).abs();
                    if (diff > 180) diff = 360 - diff;

                    /// strict tolerance
                    final facing = diff <= 3;

                    /// vibrate once when aligned
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

  Widget _buildCompass(bool facing, double heading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              /// rotating dial
              Transform.rotate(
                angle: -(heading * pi / 180),
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _CompassPainter(qiblaDirection: _qiblaDirection!),
                ),
              ),

              /// fixed center arrow (phone top)
              Icon(
                Icons.navigation,
                size: 60,
                color: facing ? Colors.green : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            facing
                ? "✔ You are facing Qibla 🕋"
                : "Turn phone to align with 🕋",
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

    final tickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 7.0;

      final angle = (i - 90) * pi / 180;

      final p1 = Offset(
        center.dx + (radius - tickLength) * cos(angle),
        center.dy + (radius - tickLength) * sin(angle),
      );

      final p2 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      canvas.drawLine(p1, p2, tickPaint);
    }

    void drawLabel(String text, double degrees, Color color) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color),
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

    /// Qibla marker
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
