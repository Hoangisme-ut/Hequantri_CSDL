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
    await tester.pumpAndSettle();

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
      (await rootBundle.load(
        'assets/images/onboarding/welcome_temple_of_literature.jpg',
      )).lengthInBytes,
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
    await tester.pumpAndSettle();

    const stories = [
      (
        'Nơi lưu giữ tinh hoa hiếu học Việt Nam',
        'assets/images/onboarding/welcome_temple_of_literature.jpg',
        'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống '
            'hiếu học và giáo dục Việt Nam.',
      ),
      (
        'Dấu ấn giao thoa của những nền văn hóa',
        'assets/images/onboarding/welcome_hoi_an.jpg',
        'Những ngôi nhà truyền thống và kiến trúc phố cổ lưu giữ dấu ấn '
            'lịch sử của thương cảng Hội An.',
      ),
      (
        'Khám phá vẻ đẹp kinh thành xưa',
        'assets/images/onboarding/welcome_thien_mu_pagoda.jpg',
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
    await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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

  testWidgets('opens the real iBeacon scanner without simulation navigation', (
    WidgetTester tester,
  ) async {
    await openAppShell(tester);

    expect(find.text('Thuyết minh Beacon'), findsOneWidget);
    expect(find.text('Chưa bắt đầu quét'), findsOneWidget);
    expect(find.text('Bắt đầu quét'), findsOneWidget);

    expect(find.byType(BeaconTestPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('SIMULATION MODE'), findsNothing);
    expect(find.text('Mô phỏng'), findsNothing);
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

  testWidgets('uses a centralized Material 3 light and dark theme', (
    WidgetTester tester,
  ) async {
    await openAppShell(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    // Verify the light theme configuration.
    expect(app.theme, isNotNull);
    expect(app.theme!.useMaterial3, isTrue);
    expect(app.theme!.colorScheme.secondary, HeritagePalette.gold);
    expect(app.theme!.colorScheme.tertiary, HeritagePalette.deepNavy);

    // Verify the dark theme configuration.
    expect(app.darkTheme, isNotNull);
    expect(app.darkTheme!.useMaterial3, isTrue);
    expect(app.darkTheme!.colorScheme.brightness, Brightness.dark);
    expect(app.darkTheme!.colorScheme.secondary, HeritagePalette.gold);
    expect(app.darkTheme!.colorScheme.tertiary, HeritagePalette.gold);

    // The application follows the device theme.
    expect(app.themeMode, ThemeMode.system);

    // Only the real iBeacon scanner is available.
    expect(find.byType(BeaconTestPage), findsOneWidget);
    expect(find.text('SIMULATION MODE'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
