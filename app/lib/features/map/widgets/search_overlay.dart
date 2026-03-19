import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';
import 'package:bobatier/features/ranking/models/ranking.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final void Function(String placeId, LatLng coords) onShopSelected;
  final List<NearbyShopPin> nearbyShops;

  const SearchOverlay({super.key, required this.onClose, required this.onShopSelected, required this.nearbyShops});

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allRankings = ref.watch(myRankingsProvider).value ?? [];
    final ranked = _query.isEmpty ? <Ranking>[] : allRankings
        .where((r) => r.shopName.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final rankedPlaceIds = allRankings.map((r) => r.placeId).toSet();
    final nearbyResults = _query.isEmpty ? <NearbyShopPin>[] : widget.nearbyShops
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .where((s) => !rankedPlaceIds.contains(s.placeId))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      decoration: InputDecoration(
                        hintText: 'Search boba shops...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        })
                            : null,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  TextButton(onPressed: widget.onClose, child: const Text('Cancel')),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _emptyState()
                  : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (ranked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('YOUR RANKED SHOPS', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    ...ranked.map(_rankedResult),
                  ],
                  if (nearbyResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('NEARBY RESULTS', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    ...nearbyResults.map(_nearbyResult),
                  ] else if (_query.isNotEmpty && ranked.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text('NEARBY RESULTS', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No shops match "$_query"',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankedResult(Ranking r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.border),
          child: const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 20),
        ),
        title: Text(r.shopName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${r.shopAddress} · ${r.drinkCount} drinks',
            style: const TextStyle(fontSize: 12)),
        trailing: TierBadge(tier: r.tier, size: 24),
        onTap: () => widget.onShopSelected(r.placeId, r.coordinates),
      ),
    );
  }

  Widget _nearbyResult(NearbyShopPin shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.border),
          child: const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 20),
        ),
        title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${shop.address.isNotEmpty ? '${shop.address} · ' : ''}★ ${shop.googleRating}',
            style: const TextStyle(fontSize: 12)),
        onTap: () => widget.onShopSelected(shop.placeId, shop.coordinates),
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Text('Type to search your ranked shops or find new ones.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
