import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bobatier/features/auth/models/app_user.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { initial, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  const AuthState({this.status = AuthStatus.initial, this.user});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  bool _handlingSignIn = false;

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_handlingSignIn) return;

    if (firebaseUser == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final profile = await _fetchProfile(firebaseUser.uid);
    if (profile == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    state = AuthState(status: AuthStatus.authenticated, user: profile);
  }

  Future<AppUser?> _fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> _storeFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmToken': token,
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token storage failed (non-fatal): $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    _handlingSignIn = true;
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      final uid = cred.user!.uid;
      await _storeFcmToken(uid);
      final user = await _fetchProfile(uid);
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } finally {
      _handlingSignIn = false;
    }
  }

  Future<void> signInWithGoogle() async {
    _handlingSignIn = true;
    try {
      final GoogleSignInAccount googleUser;
      try {
        googleUser =
            await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
      } on GoogleSignInException catch (e) {
        if (kDebugMode) debugPrint('GoogleSignInException: code=${e.code}, $e');
        if (e.code == GoogleSignInExceptionCode.canceled) return;
        rethrow;
      }

      final googleAuth = googleUser.authentication;
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        ),
      );
      final uid = cred.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(uid).set({
          'displayName': cred.user!.displayName ?? '',
          'email': cred.user!.email ?? '',
          'photoUrl': cred.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {
            'shopsRanked': 0,
            'drinksRated': 0,
            'avgScore': 0,
            'mostCommonTier': 'S',
          },
          'notifications': {
            'friendActivity': true,
            'wantToTryReminders': true,
            'newShopNearby': false,
          },
        });
      }
      await _storeFcmToken(uid);
      final user = await _fetchProfile(uid);
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } finally {
      _handlingSignIn = false;
    }
  }

  Future<void> createAccount(String name, String email, String password) async {
    _handlingSignIn = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'displayName': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'stats': {
          'shopsRanked': 0,
          'drinksRated': 0,
          'avgScore': 0,
          'mostCommonTier': 'S',
        },
        'notifications': {
          'friendActivity': true,
          'wantToTryReminders': true,
          'newShopNearby': false,
        },
      });
      await _storeFcmToken(uid);
      final user = await _fetchProfile(uid);
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } finally {
      _handlingSignIn = false;
    }
  }

  Future<void> refreshProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final user = await _fetchProfile(uid);
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    }
  }

  void signOut() {
    _auth.signOut();
    GoogleSignIn.instance.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});

final userStatsStreamProvider = StreamProvider<UserStats>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const UserStats());
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return const UserStats();
    final d = doc.data()!;
    return UserStats(
      shopsRanked: d['stats']?['shopsRanked'] ?? 0,
      drinksRated: d['stats']?['drinksRated'] ?? 0,
      avgScore: (d['stats']?['avgScore'] ?? 0).toDouble(),
      mostCommonTier: d['stats']?['mostCommonTier'] ?? 'S',
    );
  });
});
