import 'package:flutter/material.dart';

import '../../shared/widgets/heritage_widgets.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    this.onDemoContinue,
    this.onLocaleChanged,
    this.onAuthenticated,
    this.authService,
  });

  final VoidCallback? onDemoContinue;
  final ValueChanged<Locale>? onLocaleChanged;
  final ValueChanged<AuthToken>? onAuthenticated;
  final AuthService? authService;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _stories = [
    _HeritageStory(
      titleVi: 'Nơi lưu giữ tinh hoa hiếu học Việt Nam',
      descVi: 'Văn Miếu – Quốc Tử Giám là di tích lịch sử gắn với truyền thống hiếu học và giáo dục Việt Nam.',
      image: 'assets/images/onboarding/welcome_temple_of_literature.jpg',
    ),
    _HeritageStory(
      titleVi: 'Dấu ấn giao thoa của những nền văn hóa',
      descVi: 'Những ngôi nhà truyền thống và kiến trúc phố cổ lưu giữ dấu ấn lịch sử của thương cảng Hội An.',
      image: 'assets/images/onboarding/welcome_hoi_an.jpg',
    ),
    _HeritageStory(
      titleVi: 'Khám phá vẻ đẹp kinh thành xưa',
      descVi: 'Khám phá kiến trúc cung đình và giá trị lịch sử của quần thể di tích Cố đô Huế.',
      image: 'assets/images/onboarding/welcome_thien_mu_pagoda.jpg',
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
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          onDemoContinue: widget.onDemoContinue,
          onAuthenticated: widget.onAuthenticated,
          authService: widget.authService,
        ),
      ),
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
        backgroundColor: HeritagePalette.primaryNavy,
        body: PageView.builder(
          key: const Key('welcome-pages'),
          controller: _pageController,
          itemCount: _stories.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) => _WelcomeSlide(
            key: ValueKey('welcome-slide-$index'),
            story: _stories[index],
            index: index,
            pageCount: _stories.length,
            isCurrent: index == _currentPage,
            onNext: _advance,
            onSkip: _openLogin,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide({
    required this.story,
    required this.index,
    required this.pageCount,
    required this.isCurrent,
    required this.onNext,
    required this.onSkip,
    required this.onLocaleChanged,
    super.key,
  });

  final _HeritageStory story;
  final int index;
  final int pageCount;
  final bool isCurrent;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height <= 720;
    final horizontalPadding = size.width < 360 ? 20.0 : 24.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          story.image,
          key: Key('welcome-photo-$index'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: HeritagePalette.primaryNavy,
            child: Center(
              child: Icon(
                Icons.account_balance,
                color: Colors.white54,
                size: 76,
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.26, 0.54, 0.78, 1],
                colors: [
                  Color(0xE61E2A5A),
                  Color(0xAA1E2A5A),
                  Color(0x551E2A5A),
                  Color(0xB81E2A5A),
                  Color(0xF51E2A5A),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                compact ? 8 : 12,
              ),
              child: Column(
                children: [
                  _WelcomeTopBar(
                    onLocaleChanged: onLocaleChanged,
                    onSkip: onSkip,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _WelcomeBrand(compact: compact),
                        ),
                        Expanded(
                          flex: 2,
                          child: _WelcomeStoryCopy(
                            story: story,
                            index: index,
                            onTap: onNext,
                            compact: compact || constraints.maxHeight < 680,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    container: true,
                    label: 'Trang ${index + 1} trên $pageCount',
                    child: Row(
                      key: const Key('welcome-page-indicator'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pageCount,
                        (dotIndex) => AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          width: dotIndex == index ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: dotIndex == index
                                ? HeritagePalette.lavender
                                : Colors.white.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('welcome-next'),
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(compact ? 48 : 50),
                        backgroundColor: HeritagePalette.actionBlue,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        index == pageCount - 1
                            ? 'Bắt đầu khám phá'
                            : 'Tiếp tục',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeTopBar extends StatelessWidget {
  const _WelcomeTopBar({required this.onLocaleChanged, required this.onSkip});

  final ValueChanged<Locale>? onLocaleChanged;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Đổi ngôn ngữ',
          child: OutlinedButton(
            key: const Key('welcome-language-toggle'),
            onPressed: () => onLocaleChanged?.call(const Locale('en')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: const StadiumBorder(),
            ),
            child: const Text('VI'),
          ),
        ),
        const Spacer(),
        TextButton(
          key: const Key('welcome-skip'),
          onPressed: onSkip,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 38),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          ),
          child: const Text('Bỏ qua'),
        ),
      ],
    );
  }
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeritageMark(size: compact ? 58 : 66, icon: Icons.account_balance),
            SizedBox(height: compact ? 10 : 14),
            Text(
              'Smart Heritage',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontSize: compact ? 25 : 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Di sản sống trong từng hành trình',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.96),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStoryCopy extends StatelessWidget {
  const _WelcomeStoryCopy({
    required this.story,
    required this.index,
    required this.onTap,
    required this.compact,
  });

  final _HeritageStory story;
  final int index;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      key: Key('welcome-page-content-$index'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                story.titleVi,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 19 : 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: compact ? 7 : 10),
              Text(
                story.descVi,
                textAlign: TextAlign.center,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.94),
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

class _HeritageStory {
  const _HeritageStory({
    required this.titleVi,
    required this.descVi,
    required this.image,
  });

  final String titleVi;
  final String descVi;
  final String image;
}
