import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const SignalScopeApp());

/// ---------------------------------------------------------------------------
/// Theme / palette
/// ---------------------------------------------------------------------------
class AppColors {
  static const bgTop = Color(0xFF0A0F1A);
  static const bgBottom = Color(0xFF070B12);
  static const card = Color(0xFF111826);
  static const cardBorder = Color(0xFF1E2A3D);
  static const track = Color(0xFF1A2436);
  static const textDim = Color(0xFF8B98AD);

  static const accent = Color(0xFF4F9DFF);
  static const green = Color(0xFF35D07F);
  static const teal = Color(0xFF2DD4BF);
  static const amber = Color(0xFFF5B301);
  static const orange = Color(0xFFFF8A3D);
  static const red = Color(0xFFFF5470);
}

class SignalScopeApp extends StatelessWidget {
  const SignalScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Scope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.bgBottom,
      ),
      home: const DashboardScreen(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Dashboard
/// ---------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // Native channel for RSSI (see MainActivity.kt)
  static const _wifiChannel = MethodChannel('signalscope/wifi');
  final NetworkInfo _networkInfo = NetworkInfo();

  // WiFi
  int? _rssi;
  String? _ssid;
  Timer? _wifiTimer;

  // Noise
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  double? _db;
  double? _maxDb;
  bool _micGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startWifi();
    _startNoise();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wifiTimer?.cancel();
    _noiseSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the mic when backgrounded, resume when foregrounded.
    if (state == AppLifecycleState.resumed) {
      _startNoise();
      _pollWifi();
    } else if (state == AppLifecycleState.paused) {
      _noiseSub?.cancel();
      _noiseSub = null;
    }
  }

  // --- WiFi ----------------------------------------------------------------
  Future<void> _startWifi() async {
    // SSID lookup needs a location permission (and location services ON).
    await Permission.locationWhenInUse.request();
    await _pollWifi();
    _wifiTimer?.cancel();
    _wifiTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _pollWifi(),
    );
  }

  Future<void> _pollWifi() async {
    int? rssi;
    String? ssid;
    try {
      rssi = await _wifiChannel.invokeMethod<int>('getRssi');
    } catch (_) {
      // Not on WiFi, or channel unavailable — keep last known value.
    }
    try {
      ssid = await _networkInfo.getWifiName();
    } catch (_) {
      // Location off / permission denied.
    }
    if (!mounted) return;
    setState(() {
      _rssi = rssi;
      _ssid = _cleanSsid(ssid);
    });
  }

  String? _cleanSsid(String? raw) {
    if (raw == null) return null;
    var s = raw;
    // network_info_plus often wraps the SSID in quotes on Android.
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s.contains('unknown')) return null;
    return s;
  }

  // --- Noise ---------------------------------------------------------------
  Future<void> _startNoise() async {
    if (_noiseSub != null) return; // already running
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _micGranted = false);
      return;
    }
    _micGranted = true;
    _noiseMeter ??= NoiseMeter();
    _noiseSub = _noiseMeter!.noise.listen(
      _onNoise,
      onError: (_) {
        _noiseSub?.cancel();
        _noiseSub = null;
      },
      cancelOnError: true,
    );
  }

  void _onNoise(NoiseReading reading) {
    final mean = reading.meanDecibel;
    if (mean.isNaN || mean.isInfinite) return; // guard first junk samples
    if (!mounted) return;
    setState(() {
      _db = mean;
      _maxDb = reading.maxDecibel.isFinite ? reading.maxDecibel : _maxDb;
    });
  }

  // --- Build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const _Header(),
              const SizedBox(height: 24),
              _buildWifiCard(),
              const SizedBox(height: 18),
              _buildNoiseCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWifiCard() {
    final rssi = _rssi;
    final quality = rssi == null
        ? 0.0
        : ((rssi + 100) / 60).clamp(0.0, 1.0); // -100dBm..-40dBm -> 0..1
    final status = _wifiStatus(rssi);

    String _networkLabel() {
      if (_ssid != null) return _ssid!;
      if (_rssi != null) return 'Connected'; // have signal, name hidden by location
      return 'Not connected';
    }

    return GaugeCard(
      icon: Icons.wifi_rounded,
      title: 'WiFi Signal',
      progress: quality,
      centerValue: rssi == null ? '--' : '$rssi',
      unit: 'dBm',
      statusLabel: status.$1,
      color: status.$2,
      details: [
        ('Network', _networkLabel()),
        ('Quality', rssi == null ? '--' : '${(quality * 100).round()}%'),
      ],
    );
  }

  Widget _buildNoiseCard() {
    if (!_micGranted) {
      return _PermissionCard(
        icon: Icons.mic_off_rounded,
        title: 'Sound Level',
        message: 'Microphone permission is needed to measure ambient noise.',
        onRetry: () async {
          await openAppSettings();
          _startNoise();
        },
      );
    }

    final db = _db;
    final progress = db == null ? 0.0 : (db / 100).clamp(0.0, 1.0);
    final status = _noiseStatus(db);

    return GaugeCard(
      icon: Icons.graphic_eq_rounded,
      title: 'Sound Level',
      progress: progress,
      centerValue: db == null ? '--' : db.toStringAsFixed(0),
      unit: 'dB',
      statusLabel: status.$1,
      color: status.$2,
      details: [
        ('Peak', _maxDb == null ? '--' : '${_maxDb!.toStringAsFixed(0)} dB'),
        ('Mode', 'Live'),
      ],
    );
  }

  // --- Status mapping ------------------------------------------------------
  (String, Color) _wifiStatus(int? rssi) {
    if (rssi == null) return ('No signal', AppColors.textDim);
    if (rssi >= -50) return ('Excellent', AppColors.green);
    if (rssi >= -60) return ('Good', AppColors.teal);
    if (rssi >= -67) return ('Fair', AppColors.amber);
    if (rssi >= -75) return ('Weak', AppColors.orange);
    return ('Poor', AppColors.red);
  }

  (String, Color) _noiseStatus(double? db) {
    if (db == null) return ('Listening…', AppColors.textDim);
    if (db < 40) return ('Quiet', AppColors.green);
    if (db < 60) return ('Moderate', AppColors.teal);
    if (db < 75) return ('Loud', AppColors.amber);
    if (db < 85) return ('Very loud', AppColors.orange);
    return ('Harmful', AppColors.red);
  }
}

/// ---------------------------------------------------------------------------
/// Header with a pulsing "LIVE" indicator
/// ---------------------------------------------------------------------------
class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signal Scope',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live environment monitor',
                style: TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.green.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _c,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Reusable gauge card
/// ---------------------------------------------------------------------------
class GaugeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double progress; // 0..1
  final String centerValue;
  final String unit;
  final String statusLabel;
  final Color color;
  final List<(String, String)> details;

  const GaugeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.progress,
    required this.centerValue,
    required this.unit,
    required this.statusLabel,
    required this.color,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            width: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CustomPaint(
                    size: const Size(220, 220),
                    painter: _GaugePainter(progress: v, color: color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      style: TextStyle(fontSize: 14, color: AppColors.textDim),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < details.length; i++) ...[
                Expanded(child: _DetailTile(details[i].$1, details[i].$2)),
                if (i != details.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  const _DetailTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgBottom.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppColors.textDim,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 34),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textDim),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Grant access'),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Arc gauge painter
/// ---------------------------------------------------------------------------
class _GaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  static const double _start = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°
  static const double _stroke = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - _stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = AppColors.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.001) return;

    // Value arc with a gradient that follows the sweep
    final valuePaint = Paint()
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withOpacity(0.30), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * p, false, valuePaint);

    // Glowing tip
    final tipAngle = _start + _sweep * p;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(tip, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}