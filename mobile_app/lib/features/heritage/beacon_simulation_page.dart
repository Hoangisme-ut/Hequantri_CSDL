import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';

class BeaconSimulationPage extends StatefulWidget {
  const BeaconSimulationPage({super.key});

  @override
  State<BeaconSimulationPage> createState() => _BeaconSimulationPageState();
}

class _BeaconSimulationPageState extends State<BeaconSimulationPage> {
  bool _isBluetoothOn = true;
  bool _isScanning = false;
  Artifact? _detectedArtifact;
  Timer? _scanTimer;

  void _startScan() {
    setState(() {
      _isScanning = true;
      _detectedArtifact = null;
    });

    _scanTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _detectedArtifact =
              sampleArtifacts.first; // Mô phỏng tìm thấy Bình gốm hoa lam
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tham quan iBeacon Smart Tour',
          style: TextStyle(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Bluetooth Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: _isBluetoothOn ? Colors.blue : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBluetoothOn
                              ? 'Bluetooth đang bật'
                              : 'Bluetooth chưa bật',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Sẵn sàng kết nối thiết bị iBeacon tại bảo tàng',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isBluetoothOn,
                    onChanged: (val) => setState(() => _isBluetoothOn = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Radar Scan Simulation
            if (_isScanning) ...[
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                strokeWidth: 3,
                color: HeritagePalette.primaryNavy,
              ),
              const SizedBox(height: 20),
              const Text(
                'Đang quét tín hiệu iBeacon xung quanh...',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ] else if (_detectedArtifact != null) ...[
              // Detected Result Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HeritagePalette.primaryNavy),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cell_tower,
                          color: HeritagePalette.primaryNavy,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Phát hiện hiện vật gần bạn (Khoảng cách ~ 1.2m)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _detectedArtifact!.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        _detectedArtifact!.titleVi,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_detectedArtifact!.period),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HeritagePalette.primaryNavy,
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
                        child: const Text(
                          'Nghe ngay',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 40),
              const Icon(
                Icons.location_searching,
                size: 64,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nhấn nút bên dưới để quét hiện vật xung quanh',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],

            const Spacer(),

            // Scan Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isBluetoothOn && !_isScanning ? _startScan : null,
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Quét iBeacon xung quanh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HeritagePalette.primaryNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
