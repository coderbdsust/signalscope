import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/detail_tile.dart';
import '../../core/widgets/status_pill.dart';
import 'lan_device.dart';
import 'lan_device_row.dart';

enum LanViewState { offline, scanning, error, empty, ready }

class LanCard extends StatelessWidget {
  final bool connected;
  final bool scanning;
  final String? error;
  final List<LanDevice> devices;
  final String? gatewayIp;
  final String? selfIp;
  final VoidCallback onRescan;

  const LanCard({
    super.key,
    required this.connected,
    required this.scanning,
    required this.error,
    required this.devices,
    required this.gatewayIp,
    required this.selfIp,
    required this.onRescan,
  });

  LanViewState get _state {
    if (!connected) return LanViewState.offline;
    if (scanning) return LanViewState.scanning;
    if (error != null) return LanViewState.error;
    if (devices.isEmpty) return LanViewState.empty;
    return LanViewState.ready;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CardTitle(
                icon: Icons.lan_rounded,
                title: 'Local Devices',
                color: AppColors.teal,
              ),
              const Spacer(),
              _statusPill(state),
              const SizedBox(width: 8),
              if (scanning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                )
              else
                IconButton(
                  onPressed: connected ? onRescan : null,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textDim,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._body(state),
          if (state == LanViewState.ready &&
              (gatewayIp != null || selfIp != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: DetailTile('Gateway', gatewayIp ?? '--')),
                const SizedBox(width: 12),
                Expanded(child: DetailTile('Your IP', selfIp ?? '--')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(LanViewState state) => switch (state) {
        LanViewState.offline => const StatusPill('OFFLINE', AppColors.textDim),
        LanViewState.scanning => const StatusPill('SCANNING', AppColors.amber),
        LanViewState.error => const StatusPill('ERROR', AppColors.red),
        LanViewState.empty =>
          const StatusPill('NO DEVICES', AppColors.textDim),
        LanViewState.ready =>
          StatusPill('${devices.length} DEVICES', AppColors.green),
      };

  List<Widget> _body(LanViewState state) {
    switch (state) {
      case LanViewState.offline:
        return [
          const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.textDim, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connect to WiFi to scan the devices on your network.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDim,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ];
      case LanViewState.scanning:
        return [
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.amber,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Scanning network…',
                style: TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ],
          ),
        ];
      case LanViewState.error:
        return [
          Text(
            error ?? 'Scan failed.',
            style: const TextStyle(
                fontSize: 14, color: AppColors.red, height: 1.4),
          ),
        ];
      case LanViewState.empty:
        return [
          const Text(
            'No other devices found on this network.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textDim, height: 1.4),
          ),
        ];
      case LanViewState.ready:
        return [
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            LanDeviceRow(devices[i]),
          ],
          const SizedBox(height: 12),
          const Text(
            'Phones that are asleep or block scans may not appear. '
            'Your router\'s own client list is the complete source.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textDim, height: 1.4),
          ),
        ];
    }
  }
}
