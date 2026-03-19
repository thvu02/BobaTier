class FirestorePaths {
  static const users = 'users';
  static const usernames = 'usernames';
  static const friendships = 'friendships';
  static const shops = 'shops';
  static const nearbyCache = 'nearbyCache';
  static const wantToTry = 'wantToTry';

  static String userDoc(String uid) => '$users/$uid';
  static String rankings(String uid) => '$users/$uid/rankings';
  static String rankingDoc(String uid, String placeId) =>
      '$users/$uid/rankings/$placeId';
  static String usernameDoc(String username) => '$usernames/$username';

  static String friendshipId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
