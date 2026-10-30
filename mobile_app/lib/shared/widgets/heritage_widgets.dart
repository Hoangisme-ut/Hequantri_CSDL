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
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 400;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: buttonKey,
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : AppSpacing.medium,
            vertical: 12,
          ),
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          disabledBackgroundColor: colorScheme.secondary,
          disabledForegroundColor: colorScheme.onSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSecondary,
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
                  SizedBox(width: compact ? 4 : AppSpacing.small),
                  Icon(Icons.arrow_forward_rounded, size: compact ? 16 : 18),
                ],
              ),
      ),
    );
  }
}
