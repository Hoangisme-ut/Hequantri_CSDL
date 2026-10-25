import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/features/auth/login_page.dart';
import 'package:flutter_application_1/features/welcome/welcome_page.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  Future<void> openAppShell(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(appShell: AppShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('Welcome is the opening screen and starts the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Nơi lưu giữ tinh hoa hiếu học Việt Nam'), findsOneWidget);
    expect(
      find.text(
        'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống '
        'hiếu học và giáo dục Việt Nam.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(
      tester.widget<Image>(find.byKey(const Key('welcome-photo-0'))).image,
      isA<AssetImage>(),
    );
    expect(
      (await rootBundle.load('assets/images/van_mieu_welcome.jpg'))
          .lengthInBytes,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const Key('welcome-skip')));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('onboarding advances through all heritage stories to Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    const stories = [
      (
        'Nơi lưu giữ tinh hoa hiếu học Việt Nam',
        'assets/images/van_mieu_welcome.jpg',
        'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống '
            'hiếu học và giáo dục Việt Nam.',
      ),
      (
        'Dấu ấn giao thoa của những nền văn hóa',
        'assets/images/hoi_an_welcome.jpg',
        'Những ngôi nhà truyền thống và kiến trúc phố cổ lưu giữ dấu ấn '
            'lịch sử của thương cảng Hội An.',
      ),
      (
        'Khám phá vẻ đẹp kinh thành xưa',
        'assets/images/hue_welcome.jpg',
        'Khám phá kiến trúc cung đình và giá trị lịch sử của quần thể '
            'di tích Cố đô Huế.',
      ),
    ];

    for (var index = 0; index < stories.length; index++) {
      expect(find.text(stories[index].$1), findsOneWidget);
      expect(find.text(stories[index].$3), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(Key('welcome-photo-$index')),
      );
      expect(image.image, isA<AssetImage>());
      expect(
        (await rootBundle.load(stories[index].$2)).lengthInBytes,
        greaterThan(0),
      );
      expect(
        find.bySemanticsLabel('Trang ${index + 1} trên ${stories.length}'),
        findsOneWidget,
      );

      final action = find.byKey(const Key('welcome-next'));
      expect(
        find.text(
          index == stories.length - 1 ? 'Bắt đầu khám phá' : 'Tiếp tục',
        ),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('tapping the onboarding story advances one page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('welcome-page-content-0')));
    await tester.pumpAndSettle();

    expect(find.text('Dấu ấn giao thoa của những nền văn hóa'), findsOneWidget);
    expect(find.bySemanticsLabel('Trang 2 trên 3'), findsOneWidget);
  });

  testWidgets('onboarding fits small and common phone sizes without overflow', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [
      const Size(320, 700),
      const Size(360, 800),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MyApp());

      expect(find.byType(WelcomePage), findsOneWidget);
      final initialException = tester.takeException();
      expect(
        initialException,
        isNull,
        reason: 'Initial layout at viewport $size: $initialException',
      );

      for (var index = 0; index < 3; index++) {
        final action = find.byKey(const Key('welcome-next'));
        expect(
          tester.getBottomRight(action).dy,
          lessThanOrEqualTo(size.height),
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Viewport $size, page ${index + 1}');
      }

      expect(find.byType(LoginPage), findsOneWidget);
    }
  });

  testWidgets('login retains scan screen and both navigation destinations', (
    WidgetTester tester,
  ) async {
    await openAppShell(tester);

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

    await openAppShell(tester);

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
    await openAppShell(tester);

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
    await openAppShell(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.colorScheme.secondary, HeritagePalette.gold);
    expect(app.theme?.colorScheme.tertiary, HeritagePalette.deepNavy);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);
    expect(app.darkTheme?.colorScheme.secondary, HeritagePalette.gold);
    expect(app.darkTheme?.colorScheme.tertiary, HeritagePalette.gold);
    expect(app.themeMode, ThemeMode.system);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openAppShell(tester);
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pumpAndSettle();

    final simulationLabel = tester.widget<Text>(find.text('SIMULATION MODE'));
    final activeTheme = Theme.of(tester.element(find.text('SIMULATION MODE')));
    expect(activeTheme.brightness, Brightness.dark);
    expect(simulationLabel.style?.color, activeTheme.colorScheme.tertiary);
  });
}
