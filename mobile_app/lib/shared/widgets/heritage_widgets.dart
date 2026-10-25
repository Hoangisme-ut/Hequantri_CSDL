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
      label: 'Biểu tượng kiến trúc di sản',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HeritagePalette.authGold.withValues(alpha: 0.08),
            border: Border.all(
              color: HeritagePalette.authGold.withValues(alpha: 0.68),
            ),
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Icon(icon, size: size * 0.48, color: HeritagePalette.authGold),
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

    return FilledButton(
      key: buttonKey,
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        disabledBackgroundColor: colorScheme.secondary,
        disabledForegroundColor: colorScheme.onSecondary,
        shape: const StadiumBorder(),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: compact ? 4 : AppSpacing.small),
                Icon(Icons.arrow_forward_rounded, size: compact ? 16 : 18),
              ],
            ),
    );
  }
}
