import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../beacon/beacon_tools_page.dart';

/// Home/Profile entry point for the upstream live scanner and beacon tools.
class BeaconSimulationPage extends StatelessWidget {
  const BeaconSimulationPage({super.key});

  @override
  Widget build(BuildContext context) => const AppShell();
}

/// Local mock simulation kept available for isolated preview/testing.
/// It is deliberately not added to the app's primary navigation.
class BeaconSimulationPreviewPage extends StatefulWidget {
  const BeaconSimulationPreviewPage({super.key});

  @override
  State<BeaconSimulationPreviewPage> createState() =>
      _BeaconSimulationPreviewPageState();
}

class _BeaconSimulationPreviewPageState
    extends State<BeaconSimulationPreviewPage> {
  bool _isBluetoothOn = true;
  bool _isScanning = false;
  Artifact? _detectedArtifact;
  Timer? _scanTimer;

  void _startScan() {
    setState(() {
      _isScanning = true;
      _detectedArtifact = null;
    });

    _scanTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _detectedArtifact =
              sampleArtifacts.first; // Mô phỏng nhận diện hiện vật
        });
      }
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(
          isEn ? 'iBeacon Smart Tour' : 'Tham quan iBeacon Smart Tour',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bluetooth Status Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: HeritagePalette.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isBluetoothOn
                            ? HeritagePalette.actionBlue.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        Icons.bluetooth_rounded,
                        color: _isBluetoothOn
                            ? HeritagePalette.actionBlue
                            : Colors.grey,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBluetoothOn
                                ? (isEn
                                    ? 'Bluetooth is active'
                                    : 'Bluetooth đang bật')
                                : (isEn
                                    ? 'Bluetooth is off'
                                    : 'Bluetooth chưa bật'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: HeritagePalette.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? 'Ready to pair museum iBeacon sensors'
                                : 'Sẵn sàng kết nối thiết bị iBeacon tại di tích',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: HeritagePalette.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isBluetoothOn,
                      activeThumbColor: HeritagePalette.actionBlue,
                      onChanged: (val) => setState(() => _isBluetoothOn = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.large),

              // Radar Scan Simulation / Result
              if (_isScanning) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: HeritagePalette.primaryNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  isEn
                      ? 'Scanning for nearby iBeacon signals...'
                      : 'Đang quét tín hiệu iBeacon xung quanh...',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HeritagePalette.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
              ] else if (_detectedArtifact != null) ...[
                // Detected Result Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(
                      color: HeritagePalette.actionBlue.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A1E2A5A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cell_tower_rounded,
                            color: HeritagePalette.actionBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Detected nearby artifact (~1.2m)'
                                  : 'Phát hiện hiện vật gần bạn (~1.2m)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: HeritagePalette.actionBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadii.small),
                            child: Image.asset(
                              _detectedArtifact!.imageUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 68,
                                height: 68,
                                color: HeritagePalette.background,
                                child: const Icon(
                                  Icons.museum_outlined,
                                  color: HeritagePalette.secondaryText,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _detectedArtifact!.getTitle(
                                    isEn ? 'en' : 'vi',
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: HeritagePalette.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _detectedArtifact!.period,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: HeritagePalette.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HeritagePalette.background,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    strings.artifactCategory(
                                      _detectedArtifact!.category,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: HeritagePalette.actionBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: HeritagePalette.primaryNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtifactDetailPage(
                                  artifact: _detectedArtifact!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.headphones_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            isEn ? 'Listen to Audio Guide' : 'Nghe thuyết minh ngay',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 36),
                const Center(
                  child: Icon(
                    Icons.sensors_rounded,
                    size: 64,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  isEn
                      ? 'Tap button below to scan for nearby heritage artifacts'
                      : 'Nhấn nút bên dưới để quét hiện vật xung quanh',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HeritagePalette.secondaryText,
                  ),
                ),
                const SizedBox(height: 36),
              ],

              const SizedBox(height: AppSpacing.large),

              // Scan Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isBluetoothOn && !_isScanning ? _startScan : null,
                  icon: const Icon(Icons.radar_rounded, color: Colors.white),
                  label: Text(
                    isEn
                        ? 'Scan Nearby iBeacon'
                        : 'Quét iBeacon xung quanh',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: HeritagePalette.primaryNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
            ],
          ),
        ),
      ),
    );
  }
}
