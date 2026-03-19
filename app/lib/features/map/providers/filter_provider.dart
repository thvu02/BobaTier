import 'package:flutter_riverpod/legacy.dart';

enum MapFilter { none, google, myRanks }

class MapFilterState {
  final MapFilter activeFilter;
  final bool openNow;
  const MapFilterState({this.activeFilter = MapFilter.none, this.openNow = false});

  MapFilterState copyWith({MapFilter? activeFilter, bool? openNow}) =>
      MapFilterState(
        activeFilter: activeFilter ?? this.activeFilter,
        openNow: openNow ?? this.openNow,
      );
}

class MapFilterNotifier extends StateNotifier<MapFilterState> {
  MapFilterNotifier() : super(const MapFilterState());

  void setFilter(MapFilter filter) {
    if (state.activeFilter == filter) {
      state = state.copyWith(activeFilter: MapFilter.none);
    } else {
      state = state.copyWith(activeFilter: filter);
    }
  }

  void toggleOpenNow() {
    state = state.copyWith(openNow: !state.openNow);
  }
}

final mapFilterProvider = StateNotifierProvider<MapFilterNotifier, MapFilterState>(
  (ref) => MapFilterNotifier(),
);
