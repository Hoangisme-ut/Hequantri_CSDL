import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);

    final nearbyLocations = [
      {
        'nameVi': 'Văn Miếu - Quốc Tử Giám',
        'nameEn': 'Temple of Literature',
        'distance': '0.8 km',
        'address': '58 Quốc Tử Giám, Hà Nội',
        'image': 'assets/images/van_mieu_welcome.jpg',
      },
      {
        'nameVi': 'Hoàng thành Thăng Long',
        'nameEn': 'Imperial Citadel of Thang Long',
        'distance': '1.4 km',
        'address': '19C Hoàng Diệu, Hà Nội',
        'image': 'assets/images/hoi_an_welcome.jpg',
      },
    ];

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(isEn ? 'Heritage Map' : 'Bản đồ di sản'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: HeritagePalette.primaryNavy,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Simulated Interactive Map Canvas
          Container(
            color: HeritagePalette.border,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: HeritagePalette.primaryNavy,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    isEn
                        ? 'Interactive Map & GPS Navigation'
                        : 'Bản đồ tương tác di sản & GPS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HeritagePalette.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEn
                        ? 'Ready for Google Maps / Mapbox integration'
                        : 'Sẵn sàng tích hợp SDK Mapbox / Google Maps API',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HeritagePalette.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Nearby Drawer
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 210,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.large),
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEn ? 'Sites Near You' : 'Di sản gần bạn',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                        const Icon(
                          Icons.near_me_outlined,
                          size: 20,
                          color: HeritagePalette.primaryNavy,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.medium,
                      ),
                      itemCount: nearbyLocations.length,
                      itemBuilder: (context, index) {
                        final loc = nearbyLocations[index];
                        final name = isEn ? loc['nameEn']! : loc['nameVi']!;
                        final distanceBadge = isEn
                            ? '${loc['distance']} away'
                            : 'Cách ${loc['distance']}';

                        return Container(
                          width: 270,
                          margin: const EdgeInsets.only(
                            right: AppSpacing.small,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xSmall + 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: HeritagePalette.border),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
                                child: Image.asset(
                                  loc['image']!,
                                  width: 75,
                                  height: 75,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 75,
                                        height: 75,
                                        color: HeritagePalette.background,
                                        child: const Icon(
                                          Icons.account_balance_outlined,
                                          color: HeritagePalette.secondaryText,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.small),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: HeritagePalette.primaryNavy,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      loc['address']!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                HeritagePalette.secondaryText,
                                            fontSize: 11,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xSmall,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: HeritagePalette.lavender
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.small,
                                        ),
                                      ),
                                      child: Text(
                                        distanceBadge,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color:
                                                  HeritagePalette.primaryNavy,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
    );
  }
}
