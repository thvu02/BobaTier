import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bobatier/core/theme/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double size;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    this.photoUrl,
    required this.initials,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.primaryLight,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _initialsWidget(),
              errorWidget: (_, __, ___) => _initialsWidget(),
            )
          : _initialsWidget(),
    );
  }

  Widget _initialsWidget() => Center(
    child: Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.35,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );
}
