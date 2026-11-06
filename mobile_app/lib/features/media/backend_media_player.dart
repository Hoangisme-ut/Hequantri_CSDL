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

  Future<void> initialize(ArtifactMedia media, Uri origin) async {
    if (_disposed || loading || ready) return;

    loading = true;
    failed = false;
    _changed();

    try {
      final uri = mediaUri(media.url, origin);

      if (media.type == 'audio') {
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

        await player
            .setUrl(uri.toString())
            .timeout(const Duration(seconds: 20));
      } else if (media.type == 'video') {
        final player = VideoPlayerController.networkUrl(uri);
        _video = player;

        player.addListener(_videoChanged);

        await player.initialize().timeout(const Duration(seconds: 20));
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
        await (_audio?.pause() ?? _video?.pause());
      } else {
        if (completed) {
          await seek(Duration.zero);
        }

        if (_disposed || failed) return;

        final sound = _audio;

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
        } else {
          await _video?.play();
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
      await (_audio?.seek(value) ?? _video?.seekTo(value));
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

  @override
  State<BackendMediaPlayer> createState() => _BackendMediaPlayerState();
}

class _BackendMediaPlayerState extends State<BackendMediaPlayer>
    with WidgetsBindingObserver {
  BackendMediaSession? _session;
  int _selectedIndex = 0;
  bool _appActive = true;

  List<ArtifactMedia> get _items =>
      widget.media.where((item) => item.isPlayable).toList();

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
      .map((item) => '${item.id}\u0000${item.type}\u0000${item.url}')
      .join('\u0001');

  @override
  void didUpdateWidget(covariant BackendMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_signature(oldWidget.media) != _signature(widget.media) ||
        oldWidget.baseUrl != widget.baseUrl) {
      _release();
      _selectedIndex = 0;
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
    final items = _items;

    if (!_appActive || !_routeActive || items.isEmpty) return;

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
        items[_selectedIndex],
        widget.baseUrl ?? ApiConfig.baseUrl,
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

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final session = _session;
    final duration = session?.duration ?? Duration.zero;
    final position = session?.position ?? Duration.zero;
    final loading = session?.loading ?? false;
    final buffering = session?.buffering ?? false;
    final failed = session?.failed ?? false;
    final video = session?.videoController;
    final colors = Theme.of(context).colorScheme;

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
          if (items.isEmpty)
            Text(
              _text(
                'Chưa có audio hoặc video cho nội dung này.',
                'No audio or video is available for this content.',
              ),
            )
          else ...[
            if (items.length > 1)
              DropdownButton<int>(
                key: const ValueKey('media-selection'),
                isExpanded: true,
                value: _selectedIndex,
                items: [
                  for (var i = 0; i < items.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${items[i].type == 'audio' ? 'Audio' : 'Video'} ${i + 1}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (index) {
                  if (index == null || index == _selectedIndex) return;

                  _release();
                  setState(() => _selectedIndex = index);
                },
              ),
            if (items[_selectedIndex].caption?.trim().isNotEmpty ?? false)
              Text(items[_selectedIndex].caption!),
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
