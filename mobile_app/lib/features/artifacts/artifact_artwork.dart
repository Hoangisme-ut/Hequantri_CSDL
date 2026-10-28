import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'artifact.dart';

class ArtifactArtwork extends StatelessWidget {
  const ArtifactArtwork({
    required this.artifact,
    required this.height,
    super.key,
  });

  final Artifact artifact;
  final double height;

  IconData get _icon => switch (artifact.icon) {
    'drum' => Icons.album_outlined,
    'statue' => Icons.account_balance_outlined,
    'vase' => Icons.local_drink_outlined,
    'bell' => Icons.notifications_none,
    _ => Icons.dinner_dining_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final accent = Color(artifact.accent);
    return SizedBox(
      width: height * 0.88,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.88),
              accent.withValues(alpha: 0.54),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.circle_outlined,
              size: height * 0.69,
              color: Colors.white24,
            ),
            Icon(_icon, size: height * 0.39, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
