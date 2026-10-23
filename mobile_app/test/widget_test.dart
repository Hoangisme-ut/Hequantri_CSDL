import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shows the scan screen and both navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Quét iBeacon'), findsWidgets);
    expect(find.text('Chưa bắt đầu quét'), findsOneWidget);
    expect(find.text('Bắt đầu quét'), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);
    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
  });

  testWidgets('scan screen scrolls without overflowing on a short display', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('switches to simulation after scanning stops successfully', (
    WidgetTester tester,
  ) async {
    var stopRequested = false;

    await tester.pumpWidget(
      MyApp(
        appShell: AppShell(
          stopScanning: () async {
            stopRequested = true;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    expect(stopRequested, isTrue);
    expect(find.text('SIMULATION MODE'), findsOneWidget);
  });

  testWidgets('stays on scan tab when stopping scanning is not confirmed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(appShell: AppShell(stopScanning: () async => false)),
    );

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    expect(find.text('SIMULATION MODE'), findsNothing);
    expect(find.text('Quét iBeacon'), findsWidgets);
    expect(find.text('Đã dừng quét'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('navigates to simulation and preserves its behavior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    expect(find.text('SIMULATION MODE'), findsOneWidget);
    expect(
      find.textContaining(
        'These buttons do not transmit or scan Bluetooth signals.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Simulate Beacon A'));
    await tester.pump();
    expect(find.text('Notifications triggered: 1'), findsOneWidget);
    expect(find.text('Duplicate detections suppressed: 0'), findsOneWidget);
    expect(find.text('Beacon A'), findsWidgets);

    await tester.tap(find.text('Simulate Beacon A'));
    await tester.pump();
    expect(find.text('Notifications triggered: 1'), findsOneWidget);
    expect(find.text('Duplicate detections suppressed: 1'), findsOneWidget);
    expect(
      find.textContaining('Duplicate notification suppressed.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.bluetooth_searching));
    await tester.pumpAndSettle();
    expect(find.text('Chưa bắt đầu quét'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Notifications triggered: 1'), findsOneWidget);
    expect(find.text('Duplicate detections suppressed: 1'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Notifications triggered: 0'), findsOneWidget);
    expect(find.text('Duplicate detections suppressed: 0'), findsOneWidget);
    expect(find.text('No simulated beacon detected yet.'), findsOneWidget);
  });

  testWidgets('uses a centralized Material 3 light and dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.colorScheme.secondary, Colors.amber.shade700);
    expect(app.theme?.colorScheme.tertiary, Colors.teal);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);
    expect(app.darkTheme?.colorScheme.secondary, Colors.amber.shade700);
    expect(app.darkTheme?.colorScheme.tertiary, Colors.teal);
    expect(app.themeMode, ThemeMode.system);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    final simulationLabel = tester.widget<Text>(find.text('SIMULATION MODE'));
    final activeTheme = Theme.of(tester.element(find.text('SIMULATION MODE')));
    expect(activeTheme.brightness, Brightness.dark);
    expect(simulationLabel.style?.color, activeTheme.colorScheme.tertiary);
  });
}
