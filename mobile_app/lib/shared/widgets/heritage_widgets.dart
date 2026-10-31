import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HeritageMark extends StatelessWidget {
  const HeritageMark({
    this.size = 52,
    this.icon = Icons.account_balance_outlined,
    super.key,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Smart Heritage',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HeritagePalette.primaryNavy,
            border: Border.all(color: HeritagePalette.border),
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Icon(icon, size: size * 0.48, color: HeritagePalette.surface),
        ),
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.buttonKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: HeritagePalette.authCta,
          foregroundColor: HeritagePalette.surface,
          disabledBackgroundColor: HeritagePalette.authCta.withValues(
            alpha: 0.5,
          ),
          disabledForegroundColor: HeritagePalette.surface.withValues(
            alpha: 0.7,
          ),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: HeritagePalette.surface,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xSmall),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}
