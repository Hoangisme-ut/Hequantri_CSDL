import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'artifact.dart';
import 'artifact_detail_page.dart';

class ArtifactListPage extends StatefulWidget {
  const ArtifactListPage({
    super.key,
    required this.catalog,
    required this.onLocaleChanged,
  });

  final ArtifactCatalog catalog;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ArtifactListPage> createState() => _ArtifactListPageState();
}

class _ArtifactListPageState extends State<ArtifactListPage> {
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';
  final List<String> _categories = [
    'Tất cả',
    'Đồ gốm',
    'Kim loại',
    'Văn hóa',
    'Tượng điêu khắc',
  ];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    final filteredItems = widget.catalog.items.where((item) {
      final matchesCategory =
          _selectedCategory == 'Tất cả' || item.category == _selectedCategory;
      final title = item.getTitle(isEn ? 'en' : 'vi').toLowerCase();
      final period = item.period.toLowerCase();
      final location = item.location.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          period.contains(_searchQuery.toLowerCase()) ||
          location.contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(
          isEn ? 'Artifacts' : 'Hiện vật',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                final newLocale =
                    isEn ? const Locale('vi') : const Locale('en');
                widget.onLocaleChanged(newLocale);
              },
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HeritagePalette.background,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: HeritagePalette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language,
                      size: 15,
                      color: HeritagePalette.primaryNavy,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isEn ? 'EN' : 'VI',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HeritagePalette.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.xSmall,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      border: Border.all(color: HeritagePalette.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Search artifacts, period, location...'
                            : 'Tìm hiện vật, thời kỳ, địa điểm...',
                        hintStyle: const TextStyle(
                          color: HeritagePalette.secondaryText,
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: HeritagePalette.secondaryText,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  size: 18,
                                  color: HeritagePalette.secondaryText,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xSmall),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    border: Border.all(color: HeritagePalette.border),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: HeritagePalette.primaryNavy,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: 6,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                final localizedLabel = strings.artifactCategory(cat);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(localizedLabel),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: HeritagePalette.primaryNavy,
                    backgroundColor: colorScheme.surface,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : HeritagePalette.bodyText,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      side: BorderSide(
                        color: isSelected
                            ? HeritagePalette.primaryNavy
                            : HeritagePalette.border,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Artifacts List or Empty State
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState(theme, isEn)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      4,
                      AppSpacing.medium,
                      AppSpacing.medium,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildArtifactListItem(
                        context,
                        item,
                        isEn,
                        theme,
                        strings,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isEn) {
    return Center(
      child: SingleChildScrollView(
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
                  Icons.manage_search_rounded,
                  size: 32,
                  color: HeritagePalette.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                isEn ? 'No artifacts found' : 'Không tìm thấy hiện vật phù hợp',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                isEn
                    ? 'Try adjusting your search keyword or selected category.'
                    : 'Vui lòng thử lại với từ khóa khác hoặc chuyển danh mục.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedCategory = 'Tất cả';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(isEn ? 'Reset filters' : 'Đặt lại bộ lọc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HeritagePalette.actionBlue,
                  side: const BorderSide(color: HeritagePalette.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtifactListItem(
    BuildContext context,
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
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 78,
                      height: 78,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
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
                      const SizedBox(height: 4),
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
                            Icons.schedule_rounded,
                            size: 13,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.period,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.secondaryText,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.secondaryText,
                                fontSize: 12,
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
                Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: item.isFavorite
                      ? HeritagePalette.actionBlue
                      : HeritagePalette.secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
