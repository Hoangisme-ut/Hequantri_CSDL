import 'package:flutter/material.dart';

import '../../shared/widgets/heritage_widgets.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _stories = [
    _HeritageStory(
      location: 'VĂN MIẾU · HÀ NỘI',
      title: 'Nơi lưu giữ tinh hoa hiếu học Việt Nam',
      description:
          'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống '
          'hiếu học và giáo dục Việt Nam.',
      image: 'assets/images/van_mieu_welcome.jpg',
      photoCredit: 'xiquinhosilva · CC BY 2.0',
    ),
    _HeritageStory(
      location: 'PHỐ CỔ HỘI AN',
      title: 'Dấu ấn giao thoa của những nền văn hóa',
      description:
          'Những ngôi nhà truyền thống và kiến trúc phố cổ lưu giữ dấu ấn '
          'lịch sử của thương cảng Hội An.',
      image: 'assets/images/hoi_an_welcome.jpg',
      photoCredit: 'Steffen Schmitz · CC BY-SA 4.0',
    ),
    _HeritageStory(
      location: 'ĐẠI NỘI · HUẾ',
      title: 'Khám phá vẻ đẹp kinh thành xưa',
      description:
          'Khám phá kiến trúc cung đình và giá trị lịch sử của quần thể '
          'di tích Cố đô Huế.',
      image: 'assets/images/hue_welcome.jpg',
      photoCredit: 'CEphoto, Uwe Aranas · CC BY-SA 3.0',
    ),
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _advance() async {
    if (_currentPage == _stories.length - 1) {
      _openLogin();
      return;
    }

    final nextPage = _currentPage + 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(nextPage);
      return;
    }

    await _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.auth(Theme.of(context)),
      child: Scaffold(
        backgroundColor: HeritagePalette.authNavy,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final horizontalPadding = compact
                  ? AppSpacing.medium
                  : AppSpacing.large;

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.xSmall,
                      horizontalPadding,
                      AppSpacing.xSmall,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const HeritageMark(size: 38),
                              const SizedBox(width: AppSpacing.small),
                              Flexible(
                                child: Text(
                                  'SMART HERITAGE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: HeritagePalette.authText,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xSmall),
                        TextButton(
                          key: const Key('welcome-skip'),
                          onPressed: _openLogin,
                          child: const Text('Bỏ qua'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      key: const Key('welcome-pages'),
                      controller: _pageController,
                      itemCount: _stories.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final story = _stories[index];
                        return GestureDetector(
                          key: Key('welcome-page-content-$index'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _advance,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              AppSpacing.xSmall,
                              horizontalPadding,
                              AppSpacing.small,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.large,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          story.image,
                                          key: Key('welcome-photo-$index'),
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        ),
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0x33101D2A),
                                                Colors.transparent,
                                                Color(0x66101D2A),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: AppSpacing.medium,
                                          right: AppSpacing.medium,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xSmall,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: HeritagePalette.authNavy
                                                  .withValues(alpha: 0.78),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadii.small,
                                                  ),
                                              border: Border.all(
                                                color: HeritagePalette.authText
                                                    .withValues(alpha: 0.28),
                                              ),
                                            ),
                                            child: Text(
                                              story.photoCredit,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: HeritagePalette
                                                        .authText,
                                                    fontSize: 9,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: AppSpacing.medium,
                                          bottom: AppSpacing.medium,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.small,
                                              vertical: AppSpacing.xSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              color: HeritagePalette.authNavy
                                                  .withValues(alpha: 0.78),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadii.pill,
                                                  ),
                                              border: Border.all(
                                                color: HeritagePalette.authGold
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            child: Text(
                                              story.location,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: HeritagePalette
                                                        .authText,
                                                    letterSpacing: 0.8,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.medium,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DI SẢN VĂN HÓA VIỆT NAM',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: HeritagePalette.authGold,
                                                letterSpacing: 1.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.xSmall,
                                        ),
                                        Text(
                                          story.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: HeritagePalette.authText,
                                                fontSize: compact ? 21 : 23,
                                                height: 1.15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.xSmall,
                                        ),
                                        Text(
                                          story.description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: HeritagePalette.authText
                                                    .withValues(alpha: 0.78),
                                                height: 1.45,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.xSmall,
                      horizontalPadding,
                      AppSpacing.medium,
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          label:
                              'Trang ${_currentPage + 1} trên ${_stories.length}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _stories.length,
                              (index) => AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                width: index == _currentPage ? 24 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: index == _currentPage
                                      ? HeritagePalette.authGold
                                      : HeritagePalette.authText.withValues(
                                          alpha: 0.35,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        AuthSubmitButton(
                          buttonKey: const Key('welcome-next'),
                          label: _currentPage == _stories.length - 1
                              ? 'Bắt đầu khám phá'
                              : 'Tiếp tục',
                          onPressed: _advance,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeritageStory {
  const _HeritageStory({
    required this.location,
    required this.title,
    required this.description,
    required this.image,
    required this.photoCredit,
  });

  final String location;
  final String title;
  final String description;
  final String image;
  final String photoCredit;
}
