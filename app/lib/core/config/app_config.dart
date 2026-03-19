class AppConfig {
  static const _rawMapsMapId = String.fromEnvironment('MAPS_MAP_ID');
  static String? get mapsMapId => _rawMapsMapId.isEmpty ? null : _rawMapsMapId;
}