import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class BobaShop {
  final String placeId;
  final String name;
  final String address;
  final LatLng coordinates;
  final double googleRating;
  final int reviewCount;
  final String? website;
  final String? phoneNumber;
  final String? photoUrl;
  final List<OpeningPeriod> openingHours;
  final List<String> weekdayText;
  final DateTime lastSyncedAt;

  final bool? _openNowOverride;

  const BobaShop({
    required this.placeId,
    required this.name,
    required this.address,
    required this.coordinates,
    required this.googleRating,
    required this.reviewCount,
    this.website,
    this.phoneNumber,
    this.photoUrl,
    this.openingHours = const [],
    this.weekdayText = const [],
    required this.lastSyncedAt,
    bool? openNowOverride,
  }) : _openNowOverride = openNowOverride;

  factory BobaShop.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return BobaShop(
      placeId: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      coordinates: LatLng(
        (d['coordinates']?['lat'] ?? 0).toDouble(),
        (d['coordinates']?['lng'] ?? 0).toDouble(),
      ),
      googleRating: (d['googleRating'] ?? 0).toDouble(),
      reviewCount: d['reviewCount'] ?? 0,
      website: d['website'],
      phoneNumber: d['phoneNumber'],
      photoUrl: d['photoUrl'],
      openingHours: (d['openingHours']?['periods'] as List<dynamic>? ?? [])
          .map((p) => OpeningPeriod(
        openDay: p['open']?['day'] ?? 0,
        openTime: p['open']?['time'] ?? '0000',
        closeDay: p['close']?['day'] ?? 0,
        closeTime: p['close']?['time'] ?? '2359',
      ))
          .toList(),
      weekdayText: List<String>.from(d['openingHours']?['weekdayText'] ?? []),
      lastSyncedAt: (d['lastSyncedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'address': address,
    'coordinates': {'lat': coordinates.latitude, 'lng': coordinates.longitude},
    'googleRating': googleRating,
    'reviewCount': reviewCount,
    'website': website,
    'phoneNumber': phoneNumber,
    'photoUrl': photoUrl,
    'openingHours': {
      'periods': openingHours.map((p) => {
        'open': {'day': p.openDay, 'time': p.openTime},
        'close': {'day': p.closeDay, 'time': p.closeTime},
      }).toList(),
      'weekdayText': weekdayText,
    },
    'lastSyncedAt': FieldValue.serverTimestamp(),
  };

  bool get isOpenNow {
    if (_openNowOverride != null) return _openNowOverride;
    final now = DateTime.now();
    final currentDay = now.weekday % 7; // 0=Sunday, matches Google API
    final currentTime = now.hour * 100 + now.minute;

    for (final period in openingHours) {
      final open = int.tryParse(period.openTime) ?? 0;
      final close = int.tryParse(period.closeTime) ?? 2359;

      if (period.openDay == period.closeDay) {
        // Same-day period
        if (period.openDay == currentDay && currentTime >= open && currentTime <= close) {
          return true;
        }
      } else {
        // Overnight period (e.g., open Mon 2200, close Tue 0200)
        if (period.openDay == currentDay && currentTime >= open) return true;
        if (period.closeDay == currentDay && currentTime <= close) return true;
      }
    }
    return openingHours.isEmpty; // assume open if no data
  }
}

@immutable
class OpeningPeriod {
  final int openDay;
  final String openTime;
  final int closeDay;
  final String closeTime;

  const OpeningPeriod({
    required this.openDay,
    required this.openTime,
    required this.closeDay,
    required this.closeTime,
  });
}

@immutable
class NearbyShopPin {
  final String placeId;
  final String name;
  final LatLng coordinates;
  final double googleRating;
  final int reviewCount;
  final String address;
  final bool? openNow;

  const NearbyShopPin({
    required this.placeId,
    required this.name,
    required this.coordinates,
    required this.googleRating,
    required this.reviewCount,
    this.address = '',
    this.openNow,
  });

  factory NearbyShopPin.fromMap(Map<String, dynamic> d) => NearbyShopPin(
    placeId: d['placeId'] ?? '',
    name: d['name'] ?? '',
    coordinates: LatLng((d['lat'] ?? 0).toDouble(), (d['lng'] ?? 0).toDouble()),
    googleRating: (d['googleRating'] ?? 0).toDouble(),
    reviewCount: d['reviewCount'] ?? 0,
    address: d['vicinity'] ?? '',
    openNow: d['openNow'] as bool?,
  );

  Map<String, dynamic> toMap() => {
    'placeId': placeId,
    'name': name,
    'lat': coordinates.latitude,
    'lng': coordinates.longitude,
    'googleRating': googleRating,
    'reviewCount': reviewCount,
    'vicinity': address,
    'openNow': openNow,
  };

  BobaShop toBobaShop() => BobaShop(
    placeId: placeId,
    name: name,
    address: address,
    coordinates: coordinates,
    googleRating: googleRating,
    reviewCount: reviewCount,
    lastSyncedAt: DateTime.now(),
    openNowOverride: openNow,
  );
}
