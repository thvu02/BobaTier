import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class FriendMapScreen extends ConsumerStatefulWidget {
  final String friendUid;
  const FriendMapScreen({super.key, required this.friendUid});

  @override
  ConsumerState<FriendMapScreen> createState() => _FriendMapScreenState();
}

class _FriendMapScreenState extends ConsumerState<FriendMapScreen> {
  GoogleMapController? _mapController;
  static const _defaultPosition = LatLng(37.7749, -122.4194);

  double _tierHue(String tier) => switch (tier) {
    'S' => BitmapDescriptor.hueGreen,
    'A' => BitmapDescriptor.hueAzure,
    'B' => BitmapDescriptor.hueYellow,
    'C' => BitmapDescriptor.hueOrange,
    'D' => BitmapDescriptor.hueRed,
    _ => BitmapDescriptor.hueRose,
  };

  @override
  void initState() {
    super.initState();
    _moveToUserLocation();
  }

  Future<void> _moveToUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _animateTo(LatLng(lastKnown.latitude, lastKnown.longitude));
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        _animateTo(LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // Location unavailable — stay at default
    }
  }

  void _animateTo(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 13.5));
  }

  @override
  Widget build(BuildContext context) {
    final friendRankingsAsync = ref.watch(friendRankingsProvider(widget.friendUid));
    final friendsAsync = ref.watch(friendsProvider);
    final myRankings = ref.watch(myRankingsProvider).value ?? [];

    final rankings = friendRankingsAsync.value ?? [];
    final friend = friendsAsync.value?.where((f) => f.uid == widget.friendUid).firstOrNull;

    if (friend == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sTierMatch = rankings.where((r) =>
    r.tier == 'S' && myRankings.any((m) => m.placeId == r.placeId && m.tier == 'S')).length;
    final newToYou = rankings.where((r) =>
    !myRankings.any((m) => m.placeId == r.placeId)).length;

    final markers = rankings.map((r) => Marker(
      markerId: MarkerId(r.placeId),
      position: r.coordinates,
      infoWindow: InfoWindow(title: r.shopName, snippet: '${r.tier} tier'),
      icon: BitmapDescriptor.defaultMarkerWithHue(_tierHue(r.tier)),
    )).toSet();

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          AvatarWidget(photoUrl: friend.photoUrl, initials: friend.initials, size: 32),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${friend.displayName}'s map", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${friend.shopsRanked} shops · ${friend.drinksRated} drinks',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: ['S', 'A', 'B', 'C', 'D'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.tierColor(t), shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Text(t, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          )).toList()),
        ),
        Expanded(child: GoogleMap(
          initialCameraPosition: const CameraPosition(target: _defaultPosition, zoom: 13.5),
          onMapCreated: (controller) => _mapController = controller,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        )),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Shared tastes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 4),
            Text("You agree on $sTierMatch S-tier shops. You haven't tried $newToYou of ${friend.displayName.split(' ').first}'s ranked spots.",
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              _stat('$sTierMatch', 'S-tier match', AppColors.primary),
              const SizedBox(width: 8),
              _stat('$newToYou', 'New to you', AppColors.dark),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ));
  }
}

