import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    final allHistory =
        sampleArtifacts.where((e) => e.viewTime != null).toList();

    // Tab 0: Tất cả; Tab 1: Gần đây nhất (sort viewTime desc); Tab 2: Xem trước đó (sort viewTime asc)
    final historyList = switch (_tabIndex) {
      0 => allHistory,
      1 => [
          ...allHistory,
        ]..sort((a, b) => (b.viewTime ?? '').compareTo(a.viewTime ?? '')),
      _ => [
          ...allHistory,
        ]..sort((a, b) => (a.viewTime ?? '').compareTo(b.viewTime ?? '')),
    };

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: HeritagePalette.primaryNavy,
                ),
                tooltip: isEn ? 'Back' : 'Quay lại',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          isEn ? 'Visit History' : 'Lịch sử tham quan',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips: Tất cả, Gần đây, Cũ hơn
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.xSmall,
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  0,
                  isEn ? 'All (${allHistory.length})' : 'Tất cả (${allHistory.length})',
                ),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(
                  1,
                  isEn ? 'Recently Viewed' : 'Gần đây nhất',
                ),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(
                  2,
                  isEn ? 'Earlier' : 'Trước đó',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xSmall),

          // History List Items or Empty State
          Expanded(
            child: historyList.isEmpty
                ? _buildEmptyState(theme, isEn)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final item = historyList[index];
                      return _buildHistoryCard(item, isEn, theme, strings);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _tabIndex == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? HeritagePalette.primaryNavy
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected
                ? HeritagePalette.primaryNavy
                : HeritagePalette.border,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : HeritagePalette.bodyText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    Artifact item,
    bool isEn,
    ThemeData theme,
    AppStrings strings,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: HeritagePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtifactDetailPage(artifact: item),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.network(
                    item.imageUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 76,
                      height: 76,
                      color: HeritagePalette.background,
                      child: const Icon(
                        Icons.museum_outlined,
                        color: HeritagePalette.secondaryText,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              strings.artifactCategory(item.category),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: HeritagePalette.actionBlue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: HeritagePalette.secondaryText,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                item.viewTime ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: HeritagePalette.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.getTitle(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.location} • ${item.period}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.secondaryText,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
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
  }

  Widget _buildEmptyState(ThemeData theme, bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.xLarge,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: HeritagePalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: HeritagePalette.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 32,
                  color: HeritagePalette.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                isEn ? 'No visit history yet' : 'Chưa có lịch sử tham quan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                isEn
                    ? 'Heritage sites and artifacts you explore will be automatically recorded here.'
                    : 'Các địa điểm di tích và hiện vật bạn đã tham quan sẽ được tự động lưu lại tại đây.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
