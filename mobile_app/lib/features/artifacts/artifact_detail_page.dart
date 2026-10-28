import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'artifact.dart';

class ArtifactDetailPage extends StatefulWidget {
  const ArtifactDetailPage({super.key, required this.artifact});

  final Artifact artifact;

  @override
  State<ArtifactDetailPage> createState() => _ArtifactDetailPageState();
}

class _ArtifactDetailPageState extends State<ArtifactDetailPage> {
  late bool _isFav;
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  Timer? _audioTimer;

  @override
  void initState() {
    super.initState();
    _isFav = widget.artifact.isFavorite;
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    super.dispose();
  }

  void _toggleAudio() {
    setState(() => _isPlayingAudio = !_isPlayingAudio);

    if (_isPlayingAudio) {
      _audioTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          if (_audioProgress >= 1.0) {
            _audioProgress = 0.0;
            _isPlayingAudio = false;
            timer.cancel();
          } else {
            _audioProgress += 0.02;
          }
        });
      });
    } else {
      _audioTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image with back and favorite overlaid
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      child: Image.network(
                        widget.artifact.imageUrl,
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 280,
                          color: HeritagePalette.background,
                          child: const Center(
                            child: Icon(
                              Icons.account_balance_outlined,
                              size: 64,
                              color: HeritagePalette.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.xSmall,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black38,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: Colors.black38,
                              child: IconButton(
                                icon: Icon(
                                  _isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    setState(() => _isFav = !_isFav),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.medium),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.artifact.getTitle(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.artifact.period,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: HeritagePalette.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),

                      // Audio Guide Player Widget
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.small),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          border: Border.all(color: HeritagePalette.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: HeritagePalette.primaryNavy,
                                  child: IconButton(
                                    icon: Icon(
                                      _isPlayingAudio
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: _toggleAudio,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.small),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEn ? 'Audio Guide (AI Voice)' : 'Thuyết minh tự động (iBeacon Audio)',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  HeritagePalette.primaryNavy,
                                            ),
                                      ),
                                      Text(
                                        _isPlayingAudio
                                            ? (isEn
                                                  ? 'Playing audio...'
                                                  : 'Đang phát thuyết minh...')
                                            : (isEn
                                                  ? 'Tap to listen'
                                                  : 'Nhấn để nghe thuyết minh'),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  HeritagePalette.secondaryText,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xSmall),
                            LinearProgressIndicator(
                              value: _audioProgress,
                              backgroundColor: HeritagePalette.border,
                              color: HeritagePalette.primaryNavy,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.large),
                      _buildSpecRow(
                        icon: Icons.account_balance_outlined,
                        title: isEn ? 'Location' : 'Địa điểm',
                        value: widget.artifact.location,
                        theme: theme,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _buildSpecRow(
                        icon: Icons.calendar_today_outlined,
                        title: isEn ? 'Period' : 'Niên đại',
                        value: widget.artifact.period,
                        theme: theme,
                      ),
                      const SizedBox(height: AppSpacing.medium),

                      // Description section
                      Text(
                        isEn ? 'Description' : 'Mô tả',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: HeritagePalette.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xSmall),
                      Text(
                        widget.artifact.getDescription(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: HeritagePalette.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom save button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: HeritagePalette.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _isFav = !_isFav),
                  icon: Icon(
                    _isFav ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isFav
                        ? (isEn ? 'Saved' : 'Đã lưu vào yêu thích')
                        : (isEn ? 'Save to Favorites' : 'Lưu vào yêu thích'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: HeritagePalette.primaryNavy,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String title,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HeritagePalette.secondaryText, size: 20),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
