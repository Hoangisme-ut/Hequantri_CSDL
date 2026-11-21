import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/feedback/my_feedbacks_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _tokenA = AuthToken(accessToken: 'token-user-a', tokenType: 'bearer');
const _tokenB = AuthToken(accessToken: 'token-user-b', tokenType: 'bearer');

class _FakeMyFeedbacksApi implements VisitorApi {
  List<VisitorFeedback> userFeedbacks = [];
  bool throwOnLoad = false;
  bool throwOnUpdate = false;
  int updateCallCount = 0;
  String? lastUpdatedId;
  int? lastUpdatedRating;
  String? lastUpdatedComment;

  @override
  Future<VisitorPage<VisitorFeedback>> loadUserFeedbacks({
    required AuthToken token,
    int skip = 0,
    int limit = 50,
    bool includeInactive = false,
  }) async {
    if (throwOnLoad) {
      throw const VisitorApiException('Failed to load feedbacks', statusCode: 500);
    }
    return VisitorPage(
      items: userFeedbacks,
      count: userFeedbacks.length,
    );
  }

  @override
  Future<VisitorFeedback> updateFeedback({
    required AuthToken token,
    required String feedbackId,
    int? rating,
    String? comment,
  }) async {
    updateCallCount++;
    lastUpdatedId = feedbackId;
    lastUpdatedRating = rating;
    lastUpdatedComment = comment;

    if (throwOnUpdate) {
      throw const VisitorApiException('Failed to update', statusCode: 422);
    }

    final updated = VisitorFeedback(
      id: feedbackId,
      userId: '50000000-0000-0000-0000-000000000001',
      artifactId: '20000000-0000-0000-0000-000000000001',
      rating: rating ?? 5,
      comment: comment,
      status: 'pending',
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 21),
    );
    return updated;
  }

  @override
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    return const VisitorPage(
      items: [
        VisitorArtifactSummary(
          id: '20000000-0000-0000-0000-000000000001',
          siteId: '10000000-0000-0000-0000-000000000001',
          code: 'ART-01',
          era: 'Thời Lê',
          isActive: true,
          title: 'Bia Tiến sĩ',
          languageCode: 'vi',
        ),
      ],
      count: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithSession(AuthSession session, Widget child, {Locale locale = const Locale('vi')}) {
  return AuthSessionScope(
    session: session,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  late _FakeMyFeedbacksApi api;
  late AuthSession session;

  setUp(() {
    api = _FakeMyFeedbacksApi();
    session = AuthSession();
  });

  final sampleFeedbackPending = VisitorFeedback(
    id: '70000000-0000-0000-0000-000000000001',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: '20000000-0000-0000-0000-000000000001',
    rating: 5,
    comment: 'Hiện vật rất có giá trị',
    status: 'pending',
    createdAt: DateTime.utc(2026, 11, 20, 10, 30),
  );

  final sampleFeedbackApproved = VisitorFeedback(
    id: '70000000-0000-0000-0000-000000000002',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: '20000000-0000-0000-0000-000000000002',
    rating: 4,
    comment: 'Đã được duyệt',
    status: 'approved',
    createdAt: DateTime.utc(2026, 11, 19, 8, 0),
  );

  final sampleFeedbackHidden = VisitorFeedback(
    id: '70000000-0000-0000-0000-000000000003',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: '20000000-0000-0000-0000-000000000003',
    rating: 1,
    comment: 'Bình luận không phù hợp',
    status: 'hidden',
    createdAt: DateTime.utc(2026, 11, 18, 9, 0),
  );

  testWidgets('displays guest view when user is unauthenticated', (tester) async {
    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-feedbacks-guest')), findsOneWidget);
    expect(find.byKey(const Key('my-feedbacks-login-button')), findsOneWidget);
    expect(find.text('Đăng nhập để xem đánh giá'), findsOneWidget);
  });

  testWidgets('displays empty state when user has no feedbacks', (tester) async {
    session.authenticate(_tokenA);
    api.userFeedbacks = [];

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-feedbacks-empty')), findsOneWidget);
    expect(find.text(AppStrings(const Locale('vi')).feedbackEmptyTitle), findsOneWidget);
  });

  testWidgets('displays error state and allows retry', (tester) async {
    session.authenticate(_tokenA);
    api.throwOnLoad = true;

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-feedbacks-error')), findsOneWidget);
    expect(find.byKey(const Key('my-feedbacks-retry')), findsOneWidget);

    api.throwOnLoad = false;
    api.userFeedbacks = [sampleFeedbackApproved];

    await tester.tap(find.byKey(const Key('my-feedbacks-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-feedbacks-list')), findsOneWidget);
    expect(find.text('Đã được duyệt'), findsOneWidget);
  });

  testWidgets('renders feedbacks list with pending, approved, and hidden status badges', (tester) async {
    session.authenticate(_tokenA);
    api.userFeedbacks = [sampleFeedbackPending, sampleFeedbackApproved, sampleFeedbackHidden];

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-feedbacks-list')), findsOneWidget);
    expect(find.text('Bia Tiến sĩ'), findsOneWidget);
    expect(find.text('Hiện vật rất có giá trị'), findsOneWidget);
    expect(find.text('Đã được duyệt'), findsOneWidget);
    expect(find.text('Bình luận không phù hợp'), findsOneWidget);

    // Check status badges
    expect(find.text(AppStrings(const Locale('vi')).feedbackStatusPending), findsOneWidget);
    expect(find.text(AppStrings(const Locale('vi')).feedbackStatusApproved), findsOneWidget);
    expect(find.text(AppStrings(const Locale('vi')).feedbackStatusHidden), findsOneWidget);
  });

  testWidgets('clears data immediately on logout and reloads on account switch', (tester) async {
    session.authenticate(_tokenA);
    api.userFeedbacks = [sampleFeedbackPending];

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hiện vật rất có giá trị'), findsOneWidget);

    // Logout
    session.clear();
    await tester.pumpAndSettle();

    expect(find.text('Hiện vật rất có giá trị'), findsNothing);
    expect(find.byKey(const Key('my-feedbacks-guest')), findsOneWidget);

    // Login with account B
    api.userFeedbacks = [sampleFeedbackApproved];
    session.authenticate(_tokenB);
    await tester.pumpAndSettle();

    expect(find.text('Đã được duyệt'), findsOneWidget);
    expect(find.text('Hiện vật rất có giá trị'), findsNothing);
  });

  testWidgets('opens edit sheet, updates rating and comment, and reflects new status', (tester) async {
    session.authenticate(_tokenA);
    api.userFeedbacks = [sampleFeedbackApproved];

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    // Tap edit button
    await tester.tap(find.byKey(Key('edit-feedback-${sampleFeedbackApproved.id}')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings(const Locale('vi')).feedbackEditTitle), findsWidgets);
    expect(find.byKey(const Key('feedback-save-button')), findsOneWidget);

    // Change rating to 5
    await tester.tap(find.byKey(const Key('edit-rating-star-5')));
    await tester.pumpAndSettle();

    // Change comment
    await tester.enterText(find.byKey(const Key('edit-feedback-comment-field')), 'Đã cập nhật nhận xét mới');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.byKey(const Key('feedback-save-button')));
    await tester.pumpAndSettle();

    expect(api.updateCallCount, 1);
    expect(api.lastUpdatedRating, 5);
    expect(api.lastUpdatedComment, 'Đã cập nhật nhận xét mới');

    // Bottom sheet is closed, item in list reflects updated state
    expect(find.text('Đã cập nhật nhận xét mới'), findsOneWidget);
    expect(find.text(AppStrings(const Locale('vi')).feedbackUpdateSuccess), findsOneWidget);
  });

  testWidgets('displays error in edit sheet when update fails', (tester) async {
    session.authenticate(_tokenA);
    api.userFeedbacks = [sampleFeedbackApproved];
    api.throwOnUpdate = true;

    await tester.pumpWidget(
      _wrapWithSession(session, MyFeedbacksPage(api: api)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('edit-feedback-${sampleFeedbackApproved.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feedback-save-button')));
    await tester.pumpAndSettle();

    expect(api.updateCallCount, 1);
    // Sheet remains open, error is visible
    expect(find.byKey(const Key('feedback-save-button')), findsOneWidget);
  });
}
