import 'package:flutter/material.dart';
import 'package:bobatier/core/theme/app_theme.dart';

class TierBadge extends StatelessWidget {
  final String tier;
  final double size;

  const TierBadge({super.key, required this.tier, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tierColor(tier),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        tier,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TierSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const TierSelector({super.key, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['S', 'A', 'B', 'C', 'D', 'F'].map((tier) {
        final isSelected = tier == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(tier),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.tierColor(tier) : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.tierColor(tier) : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tier,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.tierColor(tier),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
