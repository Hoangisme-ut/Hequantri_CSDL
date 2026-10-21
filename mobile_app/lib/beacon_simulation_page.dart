import 'package:flutter/material.dart';

class SimulatedBeacon {
  final String name;
  final String uuid;
  final int major;
  final int minor;
  final double distance;
  final String content;

  const SimulatedBeacon({
    required this.name,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.distance,
    required this.content,
  });

  String get key => '${uuid.toLowerCase()}:$major:$minor';
}

class BeaconSimulationPage extends StatefulWidget {
  const BeaconSimulationPage({super.key});

  @override
  State<BeaconSimulationPage> createState() =>
      _BeaconSimulationPageState();
}

class _BeaconSimulationPageState
    extends State<BeaconSimulationPage> {
  static const _beaconA = SimulatedBeacon(
    name: 'Beacon A',
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 1,
    distance: 1.5,
    content: 'Sample content associated with Beacon A.',
  );

  static const _beaconB = SimulatedBeacon(
    name: 'Beacon B',
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 2,
    distance: 2.0,
    content: 'Sample content associated with Beacon B.',
  );

  SimulatedBeacon? _currentBeacon;
  String? _lastNotifiedKey;
  int _notificationCount = 0;
  int _duplicateCount = 0;
  String _status = 'Select a beacon to simulate detection.';

  void _receiveBeacon(SimulatedBeacon beacon) {
    final isDuplicate = beacon.key == _lastNotifiedKey;

    setState(() {
      _currentBeacon = beacon;

      if (isDuplicate) {
        _duplicateCount++;
        _status = '${beacon.name} detected again. '
            'Duplicate notification suppressed.';
      } else {
        _lastNotifiedKey = beacon.key;
        _notificationCount++;
        _status = 'Changed to ${beacon.name}. '
            'Content displayed and notification triggered.';
      }
    });

    debugPrint(
      '[SIMULATION] ${beacon.name} | '
      'UUID: ${beacon.uuid} | '
      'Major: ${beacon.major} | '
      'Minor: ${beacon.minor} | '
      'Simulated distance: ${beacon.distance} m | '
      'Duplicate: $isDuplicate',
    );

    // Repeated detection of the current beacon produces no new notification.
    if (isDuplicate) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('New beacon: ${beacon.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetSimulation() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _currentBeacon = null;
      _lastNotifiedKey = null;
      _notificationCount = 0;
      _duplicateCount = 0;
      _status = 'Simulation reset. Select a beacon.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final beacon = _currentBeacon;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task 4 — iBeacon Simulation'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'SIMULATION MODE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Beacon data and distances are simulated. '
              'These buttons do not transmit or scan Bluetooth signals.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _receiveBeacon(_beaconA),
                  child: const Text('Simulate Beacon A'),
                ),
                FilledButton(
                  onPressed: () => _receiveBeacon(_beaconB),
                  child: const Text('Simulate Beacon B'),
                ),
                OutlinedButton(
                  onPressed: _resetSimulation,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 16),
            Text('Notifications triggered: $_notificationCount'),
            Text('Duplicate detections suppressed: $_duplicateCount'),
            const SizedBox(height: 20),
            if (beacon == null)
              const Text('No simulated beacon detected yet.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beacon.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        'UUID: ${beacon.uuid}\n'
                        'Major: ${beacon.major}\n'
                        'Minor: ${beacon.minor}\n'
                        'Simulated distance: '
                        '${beacon.distance.toStringAsFixed(2)} m',
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Content',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(beacon.content),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}