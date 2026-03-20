import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';
import 'package:bobatier/features/ranking/models/ranking.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';

class BottomSheetCard extends StatefulWidget {
  final BobaShop shop;
  final Ranking? ranking;
  final VoidCallback onViewProfile;
  final VoidCallback onDismiss;

  const BottomSheetCard({
    super.key,
    required this.shop,
    this.ranking,
    required this.onViewProfile,
    required this.onDismiss,
  });

  @override
  State<BottomSheetCard> createState() => _BottomSheetCardState();
}

class _BottomSheetCardState extends State<BottomSheetCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > 60 || details.velocity.pixelsPerSecond.dy > 300) {
      final start = _dragOffset;
      final target = MediaQuery.of(context).size.height * 0.5;
      _animController.reset();
      _animController.addListener(() {
        setState(() {
          _dragOffset = start + (target - start) * _animController.value;
        });
      });
      _animController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismiss();
        }
      });
      _animController.forward();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  String? _todayHours() {
    if (widget.shop.weekdayText.isEmpty) return null;
    final dayIndex = DateTime.now().weekday % 7;
    final textIndex = (dayIndex == 0) ? 6 : dayIndex - 1;
    if (textIndex >= widget.shop.weekdayText.length) return null;
    return widget.shop.weekdayText[textIndex];
  }

  @override
  Widget build(BuildContext context) {
    final todayHours = _todayHours();
    final shop = widget.shop;
    final ranking = widget.ranking;

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.border,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: shop.photoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: shop.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.local_cafe, color: AppColors.textSecondary),
                                )
                              : const Icon(Icons.local_cafe, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(shop.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.dark)),
                                  ),
                                  if (ranking != null) TierBadge(tier: ranking.tier, size: 28),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text('★' * shop.googleRating.round(), style: const TextStyle(color: AppColors.amber, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text('${shop.googleRating} (${shop.reviewCount})', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (todayHours != null)
                                Text(
                                  '${shop.isOpenNow ? "Open" : "Closed"} · $todayHours',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: shop.isOpenNow ? AppColors.green : AppColors.red,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  shop.isOpenNow ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: shop.isOpenNow ? AppColors.green : AppColors.red,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onLongPress: () {
                                  Clipboard.setData(ClipboardData(text: shop.address));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 2)),
                                  );
                                },
                                child: Text(shop.address, style: Theme.of(context).textTheme.bodySmall),
                              ),
                              if (shop.website != null) ...[
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () => launchUrl(Uri.parse(shop.website!), mode: LaunchMode.externalApplication),
                                  child: Text(
                                    shop.website!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline, decorationColor: AppColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ranking == null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                        child: Text("You haven't ranked this shop yet",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onViewProfile,
                            child: Text(ranking == null ? 'View profile' : 'Rate this shop'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => launchUrl(
                              Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${shop.coordinates.latitude},${shop.coordinates.longitude}&destination_place_id=${shop.placeId}'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('Directions'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
