import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../data/heritage_repository.dart';

class HeritageDetailPage extends StatefulWidget {
  const HeritageDetailPage({super.key, required this.location});

  final HeritageLocation location;

  @override
  State<HeritageDetailPage> createState() => _HeritageDetailPageState();
}

class _HeritageDetailPageState extends State<HeritageDetailPage> {
  bool _isBookmarked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    final relatedArtifacts = sampleArtifacts
        .where(
          (item) =>
              item.location.toLowerCase().contains(
                    widget.location.nameVi.toLowerCase(),
                  ) ||
              widget.location.nameVi.toLowerCase().contains(
                    item.location.toLowerCase(),
                  ),
        )
        .toList();

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image with Overlaid Top Bar
                Stack(
                  children: [
                    Image.asset(
                      widget.location.imageUrl,
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 300,
                        color: HeritagePalette.primaryNavy,
                        child: const Center(
                          child: Icon(
                            Icons.account_balance,
                            size: 64,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    // Gradient scrim on top for back button visibility
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
                                  _isBookmarked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  color: _isBookmarked
                                      ? HeritagePalette.actionBlue
                                      : Colors.white,
                                ),
                                tooltip: isEn ? 'Bookmark' : 'Lưu di tích',
                                onPressed: () {
                                  setState(() => _isBookmarked = !_isBookmarked);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _isBookmarked
                                            ? (isEn
                                                ? 'Saved to bookmarks'
                                                : 'Đã lưu di tích vào danh sách')
                                            : (isEn
                                                ? 'Removed from bookmarks'
                                                : 'Đã bỏ lưu di tích'),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Main Info Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.large),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.location.getName(isEn ? 'en' : 'vi'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: HeritagePalette.primaryNavy,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${widget.location.rating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),

                      // Location & City Tags
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HeritagePalette.background,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              widget.location.city,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: HeritagePalette.actionBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: HeritagePalette.secondaryText,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    widget.location.address,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: HeritagePalette.secondaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large),
                      const Divider(color: HeritagePalette.border, height: 1),
                      const SizedBox(height: AppSpacing.large),

                      // Historical Background
                      Text(
                        isEn
                            ? 'Historical Background'
                            : 'Lịch sử & Giá trị văn hóa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        widget.location.getDescription(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          height: 1.65,
                          color: HeritagePalette.bodyText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xLarge),

                      // Featured Artifacts Here
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn
                                ? 'Featured Artifacts Here'
                                : 'Hiện vật trưng bày tại đây',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: HeritagePalette.primaryNavy,
                            ),
                          ),
                          Text(
                            '${relatedArtifacts.length} ${isEn ? 'items' : 'hiện vật'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: HeritagePalette.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),

                      if (relatedArtifacts.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.large),
                          decoration: BoxDecoration(
                            color: HeritagePalette.background,
                            borderRadius:
                                BorderRadius.circular(AppRadii.medium),
                            border: Border.all(color: HeritagePalette.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.museum_outlined,
                                size: 32,
                                color: HeritagePalette.secondaryText,
                              ),
                              const SizedBox(height: AppSpacing.xSmall),
                              Text(
                                isEn
                                    ? 'No artifact record linked to this location yet.'
                                    : 'Chưa có dữ liệu hiện vật lưu trữ tại địa điểm này.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: HeritagePalette.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...relatedArtifacts.map((artifact) {
                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.small,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.medium),
                              border: Border.all(color: HeritagePalette.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.medium),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.medium),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArtifactDetailPage(
                                        artifact: artifact,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(AppSpacing.small),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.small,
                                        ),
                                        child: Image.network(
                                          artifact.imageUrl,
                                          width: 58,
                                          height: 58,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) =>
                                              Container(
                                            width: 58,
                                            height: 58,
                                            color: HeritagePalette.background,
                                            child: const Icon(
                                              Icons.museum_outlined,
                                              color:
                                                  HeritagePalette.secondaryText,
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
                                            Text(
                                              artifact.getTitle(
                                                isEn ? 'en' : 'vi',
                                              ),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    HeritagePalette.primaryNavy,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              artifact.period,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: HeritagePalette
                                                    .secondaryText,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: HeritagePalette.secondaryText,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pinned Bottom Action Button
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: HeritagePalette.primaryNavy,
                          content: Text(
                            isEn
                                ? 'Demo: Navigation started to ${widget.location.nameEn}'
                                : 'Chế độ Demo: Đã bắt đầu chỉ đường đến ${widget.location.nameVi}',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.near_me_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      isEn
                          ? 'Start Tour Navigation'
                          : 'Bắt đầu chuyến tham quan',
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
          ),
        ],
      ),
    );
  }
}
