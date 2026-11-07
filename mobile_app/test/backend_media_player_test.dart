import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/media/artifact_media.dart';
import 'package:flutter_application_1/features/media/backend_media_player.dart';

const _audio = ArtifactMedia(
  id: 'audio-1',
  type: 'audio',
  url: 'https://media.test/guide.mp3',
);

const _video = ArtifactMedia(
  id: 'video-1',
  type: 'video',
  url: 'https://media.test/guide.mp4',
);

class _FakeSession extends BackendMediaSession {
  final loaded = Completer<void>();

  bool released = false;
  bool failLoad = false;
  bool _playing = false;

  int toggles = 0;
  String? receivedUrl;
  Duration? seekTarget;

  @override
  bool get playing => _playing;

  @override
  Duration get duration => const Duration(seconds: 90);

  @override
  Duration get position => const Duration(seconds: 10);

  @override
  Future<void> initialize(ArtifactMedia media, Uri origin) async {
    receivedUrl = media.url;
    loading = true;
    notifyListeners();

    await loaded.future;

    loading = false;
    ready = !failLoad;
    failed = failLoad;

    if (!released) {
      notifyListeners();
    }
  }

  @override
  Future<void> toggle() async {
    toggles++;
    _playing = !_playing;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    seekTarget = value;
    notifyListeners();
  }

  @override
  void dispose() {
    released = true;
    super.dispose();
  }
}

Widget _app(
  List<_FakeSession> sessions, {
  List<ArtifactMedia> media = const [_audio, _video],
}) {
  return MaterialApp(
    home: Scaffold(
      body: BackendMediaPlayer(
        media: media,
        isEnglish: false,
        baseUrl: Uri.parse('https://backend.test'),
        createSession: () {
          final session = _FakeSession();
          sessions.add(session);
          return session;
        },
      ),
    ),
  );
}

Future<void> _withPlayer(
  WidgetTester tester,
  Future<void> Function(List<_FakeSession> sessions) body,
) async {
  final sessions = <_FakeSession>[];

  try {
    await tester.pumpWidget(_app(sessions));
    await body(sessions);
  } finally {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpWidget(const SizedBox.shrink());

    for (final session in sessions) {
      if (!session.loaded.isCompleted) {
        session.loaded.complete();
      }
    }

    await tester.pump();
  }
}

void main() {
  test('artifact response preserves backend audio and video URLs', () {
    final content = VisitorArtifactContent.fromJson({
      'id': '20000000-0000-0000-0000-000000000001',
      'site_id': '10000000-0000-0000-0000-000000000001',
      'code': 'ART-1',
      'media': [
        {'id': _audio.id, 'media_type': _audio.type, 'url': _audio.url},
        {'id': _video.id, 'media_type': _video.type, 'url': _video.url},
      ],
    });

    expect(content.media.map((item) => item.type), ['audio', 'video']);
    expect(content.media.first.url, _audio.url);
    expect(content.media.last.url, _video.url);
  });

  test(
    'media URL resolver supports backend paths and rejects invalid URLs',
    () {
      final origin = Uri.parse('https://backend.test');

      expect(
        BackendMediaSession.mediaUri('/media/guide.mp3', origin).toString(),
        'https://backend.test/media/guide.mp3',
      );

      expect(
        BackendMediaSession.mediaUri(_audio.url, origin).toString(),
        _audio.url,
      );

      for (final value in [
        '',
        'file:///secret.mp3',
        'https://user:password@media.test/guide.mp3',
        'bad url',
      ]) {
        expect(
          () => BackendMediaSession.mediaUri(value, origin),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets('empty media does not create a playback session', (tester) async {
    final sessions = <_FakeSession>[];

    await tester.pumpWidget(_app(sessions, media: const []));

    expect(sessions, isEmpty);
    expect(
      find.text('Chưa có audio hoặc video cho nội dung này.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('media-play-pause')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loads on demand, shows loading, plays, pauses and seeks', (
    tester,
  ) async {
    await _withPlayer(tester, (sessions) async {
      expect(sessions, isEmpty);

      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      final session = sessions.single;

      expect(session.receivedUrl, _audio.url);
      expect(session.toggles, 0);
      expect(find.byKey(const ValueKey('media-loading')), findsOneWidget);

      session.loaded.complete();
      await tester.pump();

      expect(find.byKey(const ValueKey('media-loading')), findsNothing);
      expect(session.playing, isTrue);
      expect(find.text('00:10 / 01:30'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      expect(session.playing, isFalse);

      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('media-seek')),
      );
      slider.onChanged!(30000);
      await tester.pump();

      expect(session.seekTarget, const Duration(seconds: 30));
    });
  });

  testWidgets('changing resource ignores a late loading completion', (
    tester,
  ) async {
    await _withPlayer(tester, (sessions) async {
      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      final first = sessions.single;

      await tester.tap(find.byKey(const ValueKey('media-selection')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Video 2').last);
      await tester.pumpAndSettle();

      expect(first.released, isTrue);

      first.loaded.complete();
      await tester.pump();

      expect(first.toggles, 0);

      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      expect(sessions, hasLength(2));
      expect(sessions.last.receivedUrl, _video.url);

      sessions.last.loaded.complete();
      await tester.pump();

      expect(sessions.last.playing, isTrue);
    });
  });

  testWidgets('failed loading shows retry and replaces the failed session', (
    tester,
  ) async {
    await _withPlayer(tester, (sessions) async {
      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      final first = sessions.single;
      first.failLoad = true;
      first.loaded.complete();
      await tester.pump();

      expect(find.text('Thử lại'), findsOneWidget);
      expect(first.toggles, 0);

      await tester.tap(find.text('Thử lại'));
      await tester.pump();

      expect(first.released, isTrue);
      expect(sessions, hasLength(2));

      sessions.last.loaded.complete();
      await tester.pump();

      expect(sessions.last.playing, isTrue);
    });
  });

  testWidgets('updated content releases the previous player', (tester) async {
    await _withPlayer(tester, (sessions) async {
      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      final first = sessions.single;
      first.loaded.complete();
      await tester.pump();

      await tester.pumpWidget(_app(sessions, media: const [_video]));

      expect(first.released, isTrue);

      // Đổi nội dung không tự phát media mới.
      expect(sessions, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      expect(sessions, hasLength(2));
      expect(sessions.last.receivedUrl, _video.url);

      sessions.last.loaded.complete();
      await tester.pump();
    });
  });

  testWidgets('covering the detail route releases playback', (tester) async {
    await _withPlayer(tester, (sessions) async {
      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      sessions.single.loaded.complete();
      await tester.pump();

      final context = tester.element(find.byType(BackendMediaPlayer));

      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another screen')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(sessions.single.released, isTrue);
    });
  });

  testWidgets('backgrounding releases playback without autoplay on resume', (
    tester,
  ) async {
    await _withPlayer(tester, (sessions) async {
      await tester.tap(find.byKey(const ValueKey('media-play-pause')));
      await tester.pump();

      sessions.single.loaded.complete();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(sessions.single.released, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(sessions, hasLength(1));
    });
  });
}
