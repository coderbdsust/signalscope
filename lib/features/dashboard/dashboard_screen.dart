import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../lan/lan_card.dart';
import '../lan/lan_device.dart';
import '../lan/lan_service.dart';
import '../noise/noise_card.dart';
import '../noise/noise_service.dart';
import '../settings/dashboard_card.dart';
import '../settings/settings_card.dart';
import '../settings/settings_store.dart';
import '../wifi/wifi_card.dart';
import '../wifi/wifi_reading.dart';
import '../wifi/wifi_service.dart';
import 'widgets/dashboard_header.dart';

/// Owns the services + subscriptions and passes plain data to the cards.
/// Services only run while the card that needs them is enabled.
class DashboardScreen extends StatefulWidget {
  final SettingsStore settings;
  const DashboardScreen({super.key, required this.settings});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _wifiService = WifiService();
  final _noiseService = NoiseService();
  final _lanService = LanService();

  SettingsStore get _s => widget.settings;

  // WiFi
  StreamSubscription<WifiReading>? _wifiSub;
  WifiReading _wifi = WifiReading.none;

  // Noise
  StreamSubscription<NoiseSample>? _noiseSub;
  bool _startingNoise = false;
  double? _db;
  double? _maxDb;
  bool _micGranted = true;

  // LAN
  LanScanResult _lan = const LanScanResult();
  bool _scanningLan = false;
  String? _lanError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s.addListener(_onSettingsChanged);
    _syncServices();
  }

  @override
  void dispose() {
    _s.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _wifiSub?.cancel();
    _noiseSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the mic when backgrounded, resume when foregrounded.
    if (state == AppLifecycleState.resumed) {
      _startNoise();
    } else if (state == AppLifecycleState.paused) {
      _noiseSub?.cancel();
      _noiseSub = null;
    }
  }

  // --- Settings -----------------------------------------------------------
  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    _syncServices();
  }

  /// Starts/stops services to match the enabled cards.
  void _syncServices() {
    // WiFi readings are needed by the WiFi card AND the LAN card.
    final needWifi =
        _s.isEnabled(DashboardCardId.wifi) || _s.isEnabled(DashboardCardId.lan);
    if (needWifi && _wifiSub == null) {
      _startWifi();
    } else if (!needWifi && _wifiSub != null) {
      _wifiSub!.cancel();
      _wifiSub = null;
      _wifi = WifiReading.none;
    }

    // Microphone only runs while the Sound Level card is on.
    if (_s.isEnabled(DashboardCardId.noise)) {
      if (_noiseSub == null && _micGranted) _startNoise();
    } else {
      _stopNoise();
    }

    // LAN: scan when enabled while already connected.
    if (_s.isEnabled(DashboardCardId.lan) &&
        _wifi.isConnected &&
        _lan.devices.isEmpty &&
        !_scanningLan) {
      _scanLan();
    }
  }

  // --- WiFi ---------------------------------------------------------------
  void _startWifi() {
    _wifiSub = _wifiService.watch().listen(_onWifi);
  }

  void _onWifi(WifiReading reading) {
    if (!mounted) return;
    final wasUp = _wifi.isConnected;
    setState(() => _wifi = reading);
    // Scan the LAN each time the WiFi link (re)connects.
    if (reading.isConnected && !wasUp && _s.isEnabled(DashboardCardId.lan)) {
      _scanLan();
    }
  }

  // --- Noise --------------------------------------------------------------
  Future<void> _startNoise() async {
    if (_noiseSub != null || _startingNoise) return;
    if (!_s.isEnabled(DashboardCardId.noise)) return;
    _startingNoise = true;
    final granted = await _noiseService.requestPermission();
    _startingNoise = false;
    if (!mounted || !_s.isEnabled(DashboardCardId.noise)) return;
    if (!granted) {
      setState(() => _micGranted = false);
      return;
    }
    _micGranted = true;
    _noiseSub = _noiseService.samples().listen(
      _onNoise,
      onError: (_) {
        _noiseSub?.cancel();
        _noiseSub = null;
      },
      cancelOnError: true,
    );
  }

  void _stopNoise() {
    _noiseSub?.cancel();
    _noiseSub = null;
    if (_db != null || _maxDb != null) {
      setState(() {
        _db = null;
        _maxDb = null;
      });
    }
  }

  void _onNoise(NoiseSample s) {
    if (!mounted) return;
    setState(() {
      _db = s.mean;
      _maxDb = s.max ?? _maxDb;
    });
  }

  Future<void> _retryMic() async {
    await _noiseService.openSettings();
    _startNoise();
  }

  // --- LAN ----------------------------------------------------------------
  Future<void> _scanLan() async {
    if (_scanningLan || !_wifi.isConnected) return;
    setState(() {
      _scanningLan = true;
      _lanError = null;
    });
    try {
      final result = await _lanService.scan();
      if (!mounted) return;
      setState(() {
        _scanningLan = false;
        _lan = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanningLan = false;
        // Common on newer Android builds where the ARP table is restricted.
        _lanError = 'Couldn\'t scan this network — try again.';
      });
    }
  }

  // --- Build --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (_s.isEnabled(DashboardCardId.wifi)) WifiCard(reading: _wifi),
      if (_s.isEnabled(DashboardCardId.noise))
        NoiseCard(
          db: _db,
          maxDb: _maxDb,
          micGranted: _micGranted,
          onRequestPermission: _retryMic,
        ),
      if (_s.isEnabled(DashboardCardId.lan))
        LanCard(
          connected: _wifi.isConnected,
          scanning: _scanningLan,
          error: _lanError,
          devices: _lan.devices,
          gatewayIp: _lan.gatewayIp,
          selfIp: _lan.selfIp,
          onRescan: _scanLan,
        ),
    ];

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
              const DashboardHeader(),
              const SizedBox(height: 24),
              for (final c in cards) ...[c, const SizedBox(height: 18)],
              if (cards.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'All cards are turned off.\nUse the switches below to bring them back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              SettingsCard(settings: _s),
            ],
          ),
        ),
      ),
    );
  }
}
