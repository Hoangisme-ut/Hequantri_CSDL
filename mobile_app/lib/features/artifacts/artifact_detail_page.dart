import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
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

  void _toggleFavorite(bool isEn) {
    setState(() => _isFav = !_isFav);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFav
              ? (isEn
                  ? 'Saved to favorites'
                  : 'Đã lưu hiện vật vào danh sách yêu thích')
              : (isEn
                  ? 'Removed from favorites'
                  : 'Đã xóa khỏi danh sách yêu thích'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image with Overlaid Top Actions
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadii.large),
                      ),
                      child: Image.network(
                        widget.artifact.imageUrl,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 300,
                          color: HeritagePalette.primaryNavy,
                          child: const Center(
                            child: Icon(
                              Icons.museum_outlined,
                              size: 64,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient scrim on top for icons contrast
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
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
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.4),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: isEn ? 'Back' : 'Quay lại',
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.4),
                              child: IconButton(
                                icon: Icon(
                                  _isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isFav
                                      ? const Color(0xFFEF4444)
                                      : Colors.white,
                                ),
                                tooltip: isEn ? 'Favorite' : 'Yêu thích',
                                onPressed: () => _toggleFavorite(isEn),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.medium),

                // Main Content Sheet
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: HeritagePalette.border),
                        ),
                        child: Text(
                          strings.artifactCategory(widget.artifact.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HeritagePalette.actionBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),

                      // Title
                      Text(
                        widget.artifact.getTitle(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Period
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.artifact.period,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HeritagePalette.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large),

                      // Audio Guide Player Widget
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadii.medium),
                          border: Border.all(color: HeritagePalette.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Material(
                                  color: HeritagePalette.primaryNavy,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _toggleAudio,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        _isPlayingAudio
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.small),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isEn
                                                ? 'iBeacon Audio Guide'
                                                : 'Thuyết minh tự động',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  HeritagePalette.primaryNavy,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'HD Audio',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isPlayingAudio
                                            ? (isEn
                                                ? 'Playing audio guide...'
                                                : 'Đang phát thuyết minh...')
                                            : (isEn
                                                ? 'Tap to play audio guide'
                                                : 'Nhấn để nghe thuyết minh'),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: HeritagePalette.secondaryText,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.small),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              child: LinearProgressIndicator(
                                value: _audioProgress,
                                backgroundColor: HeritagePalette.background,
                                color: HeritagePalette.actionBlue,
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Structured Specs Section
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadii.medium),
                          border: Border.all(color: HeritagePalette.border),
                        ),
                        child: Column(
                          children: [
                            _buildSpecRow(
                              icon: Icons.account_balance_outlined,
                              title: isEn ? 'Location' : 'Địa điểm lưu giữ',
                              value: widget.artifact.location,
                              theme: theme,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.xSmall,
                              ),
                              child: Divider(
                                color: HeritagePalette.border,
                                height: 1,
                              ),
                            ),
                            _buildSpecRow(
                              icon: Icons.history_edu_outlined,
                              title: isEn ? 'Period' : 'Thời kỳ lịch sử',
                              value: widget.artifact.period,
                              theme: theme,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.xSmall,
                              ),
                              child: Divider(
                                color: HeritagePalette.border,
                                height: 1,
                              ),
                            ),
                            _buildSpecRow(
                              icon: Icons.category_outlined,
                              title: isEn ? 'Category' : 'Phân loại hiện vật',
                              value: strings
                                  .artifactCategory(widget.artifact.category),
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Description Section
                      Text(
                        isEn ? 'Description' : 'Mô tả chi tiết',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        widget.artifact.getDescription(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          height: 1.65,
                          color: HeritagePalette.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pinned Bottom Favorite Action Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: const Border(
                  top: BorderSide(color: HeritagePalette.border),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _toggleFavorite(isEn),
                    icon: Icon(
                      _isFav ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      _isFav
                          ? (isEn
                              ? 'Saved to Favorites'
                              : 'Đã lưu vào yêu thích')
                          : (isEn
                              ? 'Save to Favorites'
                              : 'Lưu vào yêu thích'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isFav
                          ? HeritagePalette.actionBlue
                          : HeritagePalette.primaryNavy,
                      shape: const StadiumBorder(),
                    ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: HeritagePalette.background,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Icon(
            icon,
            color: HeritagePalette.primaryNavy,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 1),
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
