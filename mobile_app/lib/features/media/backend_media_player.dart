import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:video_player/video_player.dart';

import '../../shared/config/api_config.dart';
import 'artifact_media.dart';

class BackendMediaSession extends ChangeNotifier {
  audio.AudioPlayer? _audio;
  VideoPlayerController? _video;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _disposed = false;
  bool ready = false;
  bool loading = false;
  bool failed = false;

  VideoPlayerController? get videoController => _video;

  bool get playing => _audio?.playing ?? _video?.value.isPlaying ?? false;

  bool get buffering =>
      _audio?.processingState == audio.ProcessingState.buffering ||
      (_video?.value.isBuffering ?? false);

  bool get completed =>
      _audio?.processingState == audio.ProcessingState.completed ||
      (_video?.value.isCompleted ?? false);

  Duration get position =>
      _audio?.position ?? _video?.value.position ?? Duration.zero;

  Duration get duration =>
      _audio?.duration ?? _video?.value.duration ?? Duration.zero;

  static Uri mediaUri(String value, Uri origin) {
    final text = value.trim();

    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) {
      throw const FormatException('Invalid media URL');
    }

    final uri = origin.resolveUri(Uri.parse(text));

    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid media URL');
    }

    return uri;
  }

  void _changed() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _initAudio(Uri uri) async {
    final player = audio.AudioPlayer();
    _audio = player;

    _subscriptions.add(player.playerStateStream.listen((_) => _changed()));
    _subscriptions.add(player.positionStream.listen((_) => _changed()));
    _subscriptions.add(player.durationStream.listen((_) => _changed()));
    _subscriptions.add(
      player.errorStream.listen((_) {
        if (_disposed) return;
        failed = true;
        _changed();
      }),
    );

    await player.setUrl(uri.toString()).timeout(const Duration(seconds: 20));
  }

  Future<void> _initVideo(Uri uri, {required bool muted}) async {
    final player = VideoPlayerController.networkUrl(uri);
    _video = player;

    player.addListener(_videoChanged);

    await player.initialize().timeout(const Duration(seconds: 20));
    if (muted && !_disposed) {
      await player.setVolume(0.0);
    }
  }

  Future<void> initialize(
    ArtifactMedia media,
    Uri origin, {
    ArtifactMedia? audioTrack,
  }) async {
    if (_disposed || loading || ready) return;

    loading = true;
    failed = false;
    _changed();

    try {
      final uri = mediaUri(media.url, origin);

      if (media.type == 'audio') {
        await _initAudio(uri);
      } else if (media.type == 'video') {
        if (audioTrack != null && audioTrack.type == 'audio') {
          final audioUri = mediaUri(audioTrack.url, origin);
          await Future.wait([
            _initVideo(uri, muted: true),
            _initAudio(audioUri),
          ]);
        } else {
          await _initVideo(uri, muted: false);
        }
      } else {
        throw const FormatException('Unsupported media type');
      }

      if (!_disposed) {
        ready = true;
      }
    } catch (_) {
      if (!_disposed) {
        failed = true;
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _changed();
      }
    }
  }

  void _videoChanged() {
    if (_disposed) return;

    if (_video?.value.hasError ?? false) {
      failed = true;
    }

    _changed();
  }

  Future<void> toggle() async {
    if (_disposed || !ready || failed) return;

    try {
      if (playing && !completed) {
        if (_audio != null) await _audio!.pause();
        if (_video != null) await _video!.pause();
      } else {
        if (completed) {
          await seek(Duration.zero);
        }

        if (_disposed || failed) return;

        final sound = _audio;
        final video = _video;

        if (video != null) {
          await video.play();
        }

        if (sound != null) {
          // Future của play() kết thúc khi audio phát xong.
          unawaited(
            sound.play().catchError((Object _) {
              if (!_disposed) {
                failed = true;
                _changed();
              }
            }),
          );
        }
      }
    } catch (_) {
      if (!_disposed) {
        failed = true;
      }
    }

    _changed();
  }

  Future<void> seek(Duration value) async {
    if (_disposed || !ready || failed) return;

    try {
      if (_audio != null) await _audio!.seek(value);
      if (_video != null) await _video!.seekTo(value);
    } catch (_) {
      if (!_disposed) {
        failed = true;
      }
    }

    _changed();
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;

    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();

    final sound = _audio;
    final video = _video;

    _audio = null;
    _video = null;

    if (sound != null) {
      unawaited(sound.dispose().catchError((Object _) {}));
    }

    if (video != null) {
      video.removeListener(_videoChanged);
      unawaited(video.dispose().catchError((Object _) {}));
    }

    super.dispose();
  }
}

class BackendMediaPlayer extends StatefulWidget {
  const BackendMediaPlayer({
    super.key,
    required this.media,
    required this.isEnglish,
    this.baseUrl,
    @visibleForTesting this.createSession,
  });

  final List<ArtifactMedia> media;
  final bool isEnglish;
  final Uri? baseUrl;
  final BackendMediaSession Function()? createSession;

  /// Trả về mã ngôn ngữ hiện tại ('vi' hoặc 'en').
  String get currentLangCode => isEnglish ? 'en' : 'vi';

  @override
  State<BackendMediaPlayer> createState() => _BackendMediaPlayerState();
}

class _ResolvedMedia {
  const _ResolvedMedia({
    required this.primary,
    this.accompanyingAudio,
  });

  final ArtifactMedia primary;
  final ArtifactMedia? accompanyingAudio;
}

class _BackendMediaPlayerState extends State<BackendMediaPlayer>
    with WidgetsBindingObserver {
  BackendMediaSession? _session;
  bool _appActive = true;

  /// Toàn bộ media có thể phát (audio/video).
  List<ArtifactMedia> get _items =>
      widget.media.where((item) => item.isPlayable).toList();

  /// Tự động chọn media phù hợp nhất với ngôn ngữ hiện tại.
  ///
  /// Thứ tự ưu tiên:
  ///   1. Video đúng ngôn ngữ hiện tại
  ///   2. Video dùng chung (shared) + Audio đúng ngôn ngữ hiện tại (phát đồng bộ)
  ///   3. Audio đúng ngôn ngữ hiện tại
  ///   4. Video dùng chung (shared)
  ///   5. Audio dùng chung (shared)
  ///   6. Bất kỳ media playable nào (fallback)
  _ResolvedMedia? _resolveMedia(List<ArtifactMedia> items) {
    if (items.isEmpty) return null;

    final lang = widget.currentLangCode;

    ArtifactMedia? firstWhereOrNull(bool Function(ArtifactMedia) test) {
      for (final item in items) {
        if (test(item)) return item;
      }
      return null;
    }

    // 1. Video đúng ngôn ngữ
    final langVideo = firstWhereOrNull(
      (m) => m.type == 'video' && m.languageCode == lang,
    );
    if (langVideo != null) {
      return _ResolvedMedia(primary: langVideo);
    }

    final sharedVideo = firstWhereOrNull(
      (m) => m.type == 'video' && m.languageCode == null,
    );
    final langAudio = firstWhereOrNull(
      (m) => m.type == 'audio' && m.languageCode == lang,
    );

    // 2. Video dùng chung + Audio đúng ngôn ngữ (xem video kèm thuyết minh theo ngôn ngữ)
    if (sharedVideo != null && langAudio != null) {
      return _ResolvedMedia(
        primary: sharedVideo,
        accompanyingAudio: langAudio,
      );
    }

    // 3. Chỉ có Audio đúng ngôn ngữ
    if (langAudio != null) {
      return _ResolvedMedia(primary: langAudio);
    }

    // 4. Video dùng chung
    if (sharedVideo != null) {
      return _ResolvedMedia(primary: sharedVideo);
    }

    // 5. Audio dùng chung
    final sharedAudio = firstWhereOrNull(
      (m) => m.type == 'audio' && m.languageCode == null,
    );
    if (sharedAudio != null) {
      return _ResolvedMedia(primary: sharedAudio);
    }

    // 6. Fallback
    return _ResolvedMedia(primary: items.first);
  }

  bool get _routeActive => ModalRoute.of(context)?.isCurrent ?? true;

  String _text(String vi, String en) => widget.isEnglish ? en : vi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_routeActive) {
      _release();
    }
  }

  String _signature(List<ArtifactMedia> items) => items
      .map(
        (item) =>
            '${item.id}\u0000${item.type}\u0000${item.url}\u0000${item.languageCode ?? ''}',
      )
      .join('\u0001');

  @override
  void didUpdateWidget(covariant BackendMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final mediaChanged =
        _signature(oldWidget.media) != _signature(widget.media) ||
        oldWidget.baseUrl != widget.baseUrl;
    final langChanged = oldWidget.isEnglish != widget.isEnglish;

    if (mediaChanged || langChanged) {
      // Reset session để lần phát tiếp theo dùng đúng media/ngôn ngữ mới
      _release();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;

    if (!_appActive) {
      _release();

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _release() {
    final session = _session;
    _session = null;

    session?.removeListener(_changed);
    session?.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _play({bool retry = false}) async {
    final resolved = _resolveMedia(_items);

    if (!_appActive || !_routeActive || resolved == null) return;

    if (retry || (_session?.failed ?? false)) {
      _release();
    }

    var session = _session;

    if (session == null) {
      session = widget.createSession?.call() ?? BackendMediaSession();
      session.addListener(_changed);
      _session = session;
    }

    if (session.loading) return;

    if (!session.ready) {
      await session.initialize(
        resolved.primary,
        widget.baseUrl ?? ApiConfig.baseUrl,
        audioTrack: resolved.accompanyingAudio,
      );
    }

    if (!mounted ||
        !identical(_session, session) ||
        !_appActive ||
        !_routeActive) {
      return;
    }

    if (!session.failed) {
      await session.toggle();
    }
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  String _langDisplayName(String? code) {
    if (code == 'vi') return _text('Tiếng Việt', 'Vietnamese');
    if (code == 'en') return _text('Tiếng Anh', 'English');
    if (code != null && code.isNotEmpty) return code.toUpperCase();
    return _text('Chung', 'Shared');
  }

  /// Widget label hiển thị loại media và ngôn ngữ đang được tự động chọn.
  Widget _buildAutoMediaLabel(_ResolvedMedia resolved) {
    final primary = resolved.primary;
    final audioTrack = resolved.accompanyingAudio;
    final isVideo = primary.type == 'video';
    final effectiveLangCode = audioTrack?.languageCode ?? primary.languageCode;
    final langLabel = _langDisplayName(effectiveLangCode);
    final labelText = audioTrack != null
        ? '${_text('Video + Thuyết minh', 'Video + Audio')} · $langLabel'
        : '${isVideo ? 'Video' : 'Audio'} · $langLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam_outlined : Icons.headphones_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              labelText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveMedia(_items);
    final session = _session;
    final duration = session?.duration ?? Duration.zero;
    final position = session?.position ?? Duration.zero;
    final loading = session?.loading ?? false;
    final buffering = session?.buffering ?? false;
    final failed = session?.failed ?? false;
    final video = session?.videoController;
    final colors = Theme.of(context).colorScheme;

    final activeCaption =
        resolved?.accompanyingAudio?.caption?.trim().isNotEmpty == true
        ? resolved!.accompanyingAudio!.caption!
        : (resolved?.primary.caption?.trim().isNotEmpty == true
              ? resolved!.primary.caption!
              : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text('Thuyết minh tự động', 'iBeacon Audio Guide'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (resolved == null)
            Text(
              _text(
                'Chưa có audio hoặc video cho nội dung này.',
                'No audio or video is available for this content.',
              ),
            )
          else ...[
            // Thay dropdown thủ công bằng label tự động theo ngôn ngữ
            _buildAutoMediaLabel(resolved),
            if (activeCaption != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(activeCaption),
              ),
            if (video != null && session!.ready && !failed)
              AspectRatio(
                aspectRatio: video.value.aspectRatio > 0
                    ? video.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(video),
              ),
            if ((loading || buffering) && !failed) ...[
              const LinearProgressIndicator(key: ValueKey('media-loading')),
              const SizedBox(height: 8),
              Text(_text('Đang tải media...', 'Loading media...')),
            ],
            if (failed) ...[
              Text(
                _text(
                  'Không phát được media. Kiểm tra URL hoặc kết nối mạng.',
                  'Unable to play media. Check the URL or network connection.',
                ),
                style: TextStyle(color: colors.error),
              ),
              TextButton(
                onPressed: () => _play(retry: true),
                child: Text(_text('Thử lại', 'Retry')),
              ),
            ] else
              Row(
                children: [
                  IconButton.filled(
                    key: const ValueKey('media-play-pause'),
                    tooltip:
                        (session?.playing ?? false) &&
                            !(session?.completed ?? false)
                        ? _text('Tạm dừng', 'Pause')
                        : _text('Phát', 'Play'),
                    onPressed: loading ? null : () => _play(),
                    icon: Icon(
                      (session?.playing ?? false) &&
                              !(session?.completed ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_time(position)} / ${_time(duration)}'),
                ],
              ),
            if ((session?.ready ?? false) && !failed)
              Slider(
                key: const ValueKey('media-seek'),
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, duration.inMilliseconds.toDouble())
                    .toDouble(),
                max: duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: duration.inMilliseconds > 0
                    ? (value) =>
                          session!.seek(Duration(milliseconds: value.round()))
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
