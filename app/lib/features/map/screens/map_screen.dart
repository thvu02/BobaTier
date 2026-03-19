import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';
import 'package:bobatier/features/map/providers/filter_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bobatier/features/map/providers/nearby_shops_provider.dart';
import 'package:bobatier/features/map/providers/shop_detail_provider.dart';
import 'package:bobatier/features/map/widgets/bottom_sheet_card.dart';
import 'package:bobatier/features/map/widgets/search_overlay.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';
import 'package:bobatier/shared/avatar_widget.dart';

import '../../../core/config/app_config.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  String? _selectedPlaceId;
  bool _showSearch = false;
  bool _locationGranted = false;
  bool _resolving = true;
  LatLng? _pendingCenter;

  static const _sfCenter = LatLng(37.7749, -122.4194);
  LatLng _initialCenter = _sfCenter;

  @override
  void initState() {
    super.initState();
    _resolveInitialCenter();
  }

  Future<void> _resolveInitialCenter() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _locationGranted = true;

        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _initialCenter = LatLng(lastKnown.latitude, lastKnown.longitude);
        }

        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 8),
            ),
          );
          _initialCenter = LatLng(position.latitude, position.longitude);
        } catch (_) {
          // getLastKnownPosition fallback already applied above
        }
      }
    } catch (_) {
      // Fall back to SF default
    }
    ref.read(mapCenterProvider.notifier).state = _initialCenter;
    if (mounted) {
      setState(() => _resolving = false);
      if (_locationGranted && _initialCenter != _sfCenter) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_initialCenter),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _pendingCenter = position.target;
  }

  void _onCameraIdle() {
    if (_pendingCenter != null) {
      ref.read(mapCenterProvider.notifier).state = _pendingCenter!;
      _pendingCenter = null;
    }
  }

  void _ensureShopCached(NearbyShopPin shop) {
    FirebaseFunctions.instance.httpsCallable('onPlaceDetail').call({
      'placeId': shop.placeId,
    }).ignore();
  }

  double _tierHue(String tier) => switch (tier) {
    'S' => BitmapDescriptor.hueYellow,
    'A' => BitmapDescriptor.hueAzure,
    'B' => BitmapDescriptor.hueCyan,
    'C' => BitmapDescriptor.hueGreen,
    'D' => BitmapDescriptor.hueOrange,
    'F' => BitmapDescriptor.hueRose,
    _ => BitmapDescriptor.hueRed,
  };

  Set<Marker> _buildMarkers(
      List<NearbyShopPin> shops,
      List<dynamic> rankings,
      MapFilterState filterState,
      Map<String, BobaShop?> shopDetailsCache,
      ) {
    final rankMap = {for (final r in rankings) r.placeId: r};
    final markers = <Marker>{};

    for (final shop in shops) {
      final detail = shopDetailsCache[shop.placeId];
      final isOpen = detail != null ? detail.isOpenNow : (shop.openNow ?? true);
      final isClosed = filterState.openNow && !isOpen;

      final ranking = rankMap[shop.placeId];
      final isRanked = ranking != null;

      double hue;
      switch (filterState.activeFilter) {
        case MapFilter.google:
          hue = 210.0;
        case MapFilter.myRanks:
          hue = isRanked ? _tierHue(ranking.tier) : BitmapDescriptor.hueRed;
        case MapFilter.none:
          hue = BitmapDescriptor.hueRed;
      }

      markers.add(Marker(
        markerId: MarkerId(shop.placeId),
        position: shop.coordinates,
        infoWindow: InfoWindow(
          title: shop.name,
          snippet: isRanked ? '${ranking.tier} tier' : '★ ${shop.googleRating}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        alpha: () {
          double a = 1.0;
          if (filterState.activeFilter == MapFilter.myRanks && !isRanked) a = 0.25;
          if (isClosed) a = a * 0.35;
          return a;
        }(),
        onTap: () {
          setState(() => _selectedPlaceId = shop.placeId);
          _ensureShopCached(shop);
        },
      ));
    }
    return markers;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filterState = ref.watch(mapFilterProvider);
    final nearbyAsync = ref.watch(nearbyShopsProvider);
    final rankings = ref.watch(myRankingsProvider).value ?? [];
    final user = ref.watch(currentUserProvider);
    final shops = nearbyAsync.value ?? [];

    // Build details cache for open-now computation
    final shopDetailsCache = <String, BobaShop?>{};
    if (filterState.openNow) {
      for (final shop in shops) {
        final detail = ref.watch(shopDetailProvider(shop.placeId)).value;
        if (detail != null) shopDetailsCache[shop.placeId] = detail;
      }
    }
    final selectedPin = _selectedPlaceId != null
        ? shops.where((s) => s.placeId == _selectedPlaceId).firstOrNull
        : null;
    final selectedRanking = _selectedPlaceId != null
        ? ref.watch(shopRankingProvider(_selectedPlaceId!))
        : null;
    final fullShopAsync = _selectedPlaceId != null
        ? ref.watch(shopDetailProvider(_selectedPlaceId!))
        : null;
    final selectedShop = fullShopAsync?.value ?? selectedPin?.toBobaShop();

    if (_showSearch) {
      return SearchOverlay(
        nearbyShops: shops,
        onClose: () => setState(() => _showSearch = false),
        onShopSelected: (placeId, coords) {
          setState(() {
            _showSearch = false;
            _selectedPlaceId = placeId;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(coords));
        },
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          if (_resolving)
            const Center(child: CircularProgressIndicator())
          else
          GoogleMap(
            mapId: AppConfig.mapsMapId,
            initialCameraPosition: CameraPosition(target: _initialCenter, zoom: 14.5),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: _buildMarkers(shops, rankings, filterState, shopDetailsCache),
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 110),
            onTap: (_) => setState(() => _selectedPlaceId = null),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showSearch = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Search boba shops...', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: AvatarWidget(
                          photoUrl: user?.photoUrl,
                          initials: user?.initials ?? '?',
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _filterChips(filterState),
                ],
              ),
            ),
          ),
          if (nearbyAsync.isLoading && !_resolving)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Finding boba shops...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (nearbyAsync.hasError)
            Positioned(
              bottom: selectedShop != null ? 180 : 16,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Could not load nearby shops',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(nearbyShopsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!nearbyAsync.isLoading && !nearbyAsync.hasError && shops.isEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.amberBg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.amber, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No boba shops found nearby. Try panning the map.',
                          style: TextStyle(color: AppColors.dark, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(nearbyShopsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (filterState.activeFilter == MapFilter.myRanks)
            Positioned(
              bottom: selectedShop != null ? 190 : 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['S', 'A', 'B', 'C', 'D', 'F'].map((tier) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.tierColor(tier),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(tier, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (selectedShop != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: BottomSheetCard(
                shop: selectedShop,
                ranking: selectedRanking,
                onViewProfile: () => context.push('/shop/${selectedShop.placeId}'),
                onDismiss: () => setState(() => _selectedPlaceId = null),
              ),
            ),
          if (_locationGranted)
            Positioned(
              bottom: selectedShop != null ? 190 : 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'myLocation',
                backgroundColor: AppColors.card,
                foregroundColor: AppColors.primary,
                elevation: 2,
                onPressed: () async {
                  try {
                    final position = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(timeLimit: Duration(seconds: 5)),
                    );
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
                    );
                  } catch (_) {
                    // Fall back to last known
                    final last = await Geolocator.getLastKnownPosition();
                    if (last != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(LatLng(last.latitude, last.longitude)),
                      );
                    }
                  }
                },
                child: const Icon(Icons.my_location, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChips(MapFilterState state) {
    final notifier = ref.read(mapFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Google', state.activeFilter == MapFilter.google, () => notifier.setFilter(MapFilter.google), activeColor: AppColors.amber),
          const SizedBox(width: 6),
          _chip('My ranks', state.activeFilter == MapFilter.myRanks, () => notifier.setFilter(MapFilter.myRanks)),
          const SizedBox(width: 6),
          _chip('Open now', state.openNow, () => notifier.toggleOpenNow()),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap, {Color? activeColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? (activeColor ?? AppColors.primary) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? (activeColor ?? AppColors.primary) : AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
