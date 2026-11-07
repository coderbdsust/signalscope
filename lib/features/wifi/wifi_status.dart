import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

(String, Color) wifiStatus(int? rssi) {
  if (rssi == null) return ('No signal', AppColors.textDim);
  if (rssi >= -50) return ('Excellent', AppColors.green);
  if (rssi >= -60) return ('Good', AppColors.teal);
  if (rssi >= -67) return ('Fair', AppColors.amber);
  if (rssi >= -75) return ('Weak', AppColors.orange);
  return ('Poor', AppColors.red);
}
