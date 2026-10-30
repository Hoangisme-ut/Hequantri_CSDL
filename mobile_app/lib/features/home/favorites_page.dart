import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);
    final allFavs = sampleArtifacts.where((e) => e.isFavorite).toList();
    // Artifacts: non-location items; Locations: Địa điểm category
    final artifactFavs = allFavs
        .where((e) => e.category != 'Địa điểm')
        .toList();
    final locationFavs = allFavs
        .where((e) => e.category == 'Địa điểm')
        .toList();
    final favList = _tabIndex == 0
        ? allFavs
        : _tabIndex == 1
        ? artifactFavs
        : locationFavs;

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: HeritagePalette.primaryNavy,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          isEn ? 'Favorites' : 'Yêu thích',
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
          // Filter Tabs (Tất cả, Hiện vật, Địa điểm)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.xSmall,
            ),
            child: Row(
              children: [
                _buildFilterTab(
                  0,
                  isEn
                      ? 'All (${allFavs.length})'
                      : 'Tất cả (${allFavs.length})',
                ),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterTab(
                  1,
                  isEn
                      ? 'Artifacts (${artifactFavs.length})'
                      : 'Hiện vật (${artifactFavs.length})',
                ),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterTab(
                  2,
                  isEn
                      ? 'Locations (${locationFavs.length})'
                      : 'Địa điểm (${locationFavs.length})',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xSmall),

          // List Items
          Expanded(
            child: favList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 56,
                          color: HeritagePalette.border,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          isEn
                              ? 'No favorites yet'
                              : 'Chưa có mục yêu thích nào',
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
                    itemCount: favList.length,
                    itemBuilder: (context, index) {
                      final item = favList[index];
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
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 76,
                                        height: 76,
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
                                    Text(
                                      item.category,
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
                              const Icon(
                                Icons.favorite,
                                color: HeritagePalette.primaryNavy,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xSmall),
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

  Widget _buildFilterTab(int index, String label) {
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
