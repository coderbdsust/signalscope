import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

(String, Color) noiseStatus(double? db) {
  if (db == null) return ('Listening…', AppColors.textDim);
  if (db < 40) return ('Quiet', AppColors.green);
  if (db < 60) return ('Moderate', AppColors.teal);
  if (db < 75) return ('Loud', AppColors.amber);
  if (db < 85) return ('Very loud', AppColors.orange);
  return ('Harmful', AppColors.red);
}
