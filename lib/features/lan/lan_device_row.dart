import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'lan_device.dart';

class LanDeviceRow extends StatelessWidget {
  final LanDevice device;
  const LanDeviceRow(this.device, {super.key});

  Color get _color => device.isGateway
      ? AppColors.teal
      : device.isSelf
          ? AppColors.accent
          : Colors.white;

  String? get _badge => device.isGateway
      ? 'GATEWAY'
      : device.isSelf
          ? 'THIS DEVICE'
          : null;

  String get _macText {
    if (device.hasMac) return device.mac;
    return device.isSelf ? 'MAC hidden by Android' : 'MAC unavailable';
  }

  /// "Apple, Inc." / "Private MAC" / null
  String? get _vendorText {
    if (device.vendor != null) return device.vendor;
    if (device.isPrivateMac) return 'Private (randomized) MAC';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final badge = _badge;
    final vendor = _vendorText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgBottom.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(device.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + role badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Type  ·  IP
                Text(
                  '${device.type.label}  ·  ${device.ip}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: color == Colors.white ? AppColors.accent : color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                // MAC (always shown)
                Text(
                  _macText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: device.hasMac ? Colors.white70 : AppColors.textDim,
                    letterSpacing: 0.5,
                  ),
                ),
                if (vendor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    vendor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
