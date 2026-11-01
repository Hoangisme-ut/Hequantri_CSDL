import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/home/history_page.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';

const _token = AuthToken(accessToken: 'visitor-token', tokenType: 'bearer');

VisitHistoryEntry _entry(String id, String title) => VisitHistoryEntry(
  visit: VisitRecord(
    id: id,
    artifactId: 'artifact-$id',
    visitedAt: DateTime.utc(2026, 11, 1),
  ),
  code: 'ART-$id',
  title: title,
);

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

class _HistoryService extends VisitLogService {
  _HistoryService() : super(baseUrl: Uri.parse('http://localhost:8000'));
  final List<int> offsets = [];
  bool fail = false;
  Completer<VisitHistoryResult>? pending;

  @override
  Future<VisitHistoryResult> history({
    required AuthToken token,
    String languageCode = 'vi',
    int skip = 0,
    int limit = 20,
  }) async {
    offsets.add(skip);
    if (fail) throw const VisitLogException('Lỗi máy chủ lịch sử.');
    if (pending != null) return pending!.future;
    return VisitHistoryResult(
      entries: [
        _entry(
          skip == 0 ? '1' : '2',
          skip == 0 ? 'Đoan Môn' : 'Điện Kính Thiên',
        ),
      ],
      count: 2,
    );
  }
}

void main() {
  testWidgets('history reads real records with pagination and refresh', (
    tester,
  ) async {
    final service = _HistoryService();
    addTearDown(service.close);
    await tester.pumpWidget(
      _app(HistoryPage(service: service, readToken: () => _token)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đoan Môn'), findsOneWidget);
    expect(find.text('Tổng lượt xem: 2'), findsOneWidget);
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Điện Kính Thiên'), findsOneWidget);
    expect(service.offsets, [0, 1]);
    expect(find.text('Xem thêm'), findsNothing);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(service.offsets, [0, 1, 0]);
    expect(find.text('Điện Kính Thiên'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('demo sessions do not fetch fake history', (tester) async {
    final service = _HistoryService();
    addTearDown(service.close);
    await tester.pumpWidget(
      _app(HistoryPage(service: service, readToken: () => null)),
    );
    await tester.pumpAndSettle();
    expect(service.offsets, isEmpty);
    expect(
      find.text('Vui lòng đăng nhập để xem lịch sử tham quan.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history errors can be retried', (tester) async {
    final service = _HistoryService()..fail = true;
    addTearDown(service.close);
    await tester.pumpWidget(
      _app(HistoryPage(service: service, readToken: () => _token)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lỗi máy chủ lịch sử.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đoan Môn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('logout clears history and ignores the old account response', (
    tester,
  ) async {
    final service = _HistoryService()
      ..pending = Completer<VisitHistoryResult>();
    final session = AuthSession()..authenticate(_token);
    addTearDown(() {
      service.close();
      session.dispose();
    });
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: _app(HistoryPage(service: service)),
      ),
    );
    await tester.pump();
    session.clear();
    await tester.pump();
    service.pending!.complete(
      VisitHistoryResult(
        entries: [_entry('1', 'Old account content')],
        count: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old account content'), findsNothing);
    expect(
      find.text('Vui lòng đăng nhập để xem lịch sử tham quan.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
