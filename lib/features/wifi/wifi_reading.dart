class WifiReading {
  final int? rssi;
  final String? ssid;
  const WifiReading({this.rssi, this.ssid});

  bool get isConnected => rssi != null;

  /// -100 dBm..-40 dBm -> 0..1
  double get quality =>
      rssi == null ? 0.0 : ((rssi! + 100) / 60).clamp(0.0, 1.0);

  static const none = WifiReading();
}
