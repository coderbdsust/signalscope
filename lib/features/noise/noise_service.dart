import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class NoiseSample {
  final double mean;
  final double? max;
  const NoiseSample(this.mean, this.max);
}

class NoiseService {
  NoiseMeter? _meter;

  Future<bool> requestPermission() async =>
      (await Permission.microphone.request()).isGranted;

  /// Live samples; guards against the NaN/infinite first readings.
  Stream<NoiseSample> samples() {
    _meter ??= NoiseMeter();
    return _meter!.noise
        .where((r) => r.meanDecibel.isFinite)
        .map((r) => NoiseSample(
              r.meanDecibel,
              r.maxDecibel.isFinite ? r.maxDecibel : null,
            ));
  }

  Future<void> openSettings() => openAppSettings();
}
