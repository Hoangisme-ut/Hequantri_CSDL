import 'package:flutter/material.dart';

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
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);
    final allHistory = sampleArtifacts
        .where((e) => e.viewTime != null)
        .toList();

    // Tab 0: Tất cả; Tab 1: Xem nhiều (sort by viewTime asc — sớm nhất = xem nhiều hơn theo mock);
    // Tab 2: Gần đây — sort by viewTime desc (mới nhất trước)
    final historyList = switch (_tabIndex) {
      0 => allHistory,
      1 => [
        ...allHistory,
      ]..sort((a, b) => (a.viewTime ?? '').compareTo(b.viewTime ?? '')),
      _ => [
        ...allHistory,
      ]..sort((a, b) => (b.viewTime ?? '').compareTo(a.viewTime ?? '')),
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isEn ? 'History' : 'Lịch sử',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips: Tất cả, Xem nhiều, Gần đây
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.xSmall,
            ),
            child: Row(
              children: [
                _buildFilterChip(0, isEn ? 'All' : 'Tất cả'),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(1, isEn ? 'Most Viewed' : 'Xem nhiều'),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(2, isEn ? 'Recently Viewed' : 'Gần đây'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xSmall),

          // History List Items
          Expanded(
            child: historyList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 56,
                          color: HeritagePalette.border,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          isEn
                              ? 'No visit history yet'
                              : 'Chưa có lịch sử tham quan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HeritagePalette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final item = historyList[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ArtifactDetailPage(artifact: item),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.small,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xSmall + 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                            border: Border.all(color: HeritagePalette.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 70,
                                        height: 70,
                                        color: HeritagePalette.background,
                                        child: const Icon(
                                          Icons.account_balance_outlined,
                                          color: HeritagePalette.secondaryText,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.medium),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.getTitle(isEn ? 'en' : 'vi'),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: HeritagePalette.primaryNavy,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.period,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                HeritagePalette.secondaryText,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: HeritagePalette.secondaryText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.viewTime ?? '',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: HeritagePalette
                                                    .secondaryText,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
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
          vertical: AppSpacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? HeritagePalette.primaryNavy
              : HeritagePalette.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : HeritagePalette.secondaryText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
