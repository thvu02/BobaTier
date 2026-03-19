import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';
import 'package:bobatier/features/auth/screens/login_screen.dart';
import 'package:bobatier/features/auth/screens/register_screen.dart';
import 'package:bobatier/features/auth/screens/username_screen.dart';
import 'package:bobatier/features/auth/screens/location_permission_screen.dart';
import 'package:bobatier/features/map/screens/map_screen.dart';
import 'package:bobatier/features/ranking/screens/shop_profile_screen.dart';
import 'package:bobatier/features/ranking/screens/rate_drink_screen.dart';
import 'package:bobatier/features/ranking/screens/tier_list_screen.dart';
import 'package:bobatier/features/social/screens/friends_screen.dart';
import 'package:bobatier/features/social/screens/add_friends_screen.dart';
import 'package:bobatier/features/social/screens/friend_map_screen.dart';
import 'package:bobatier/features/social/screens/friend_profile_screen.dart';
import 'package:bobatier/features/profile/screens/profile_screen.dart';
import 'package:bobatier/shared/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.initial) return null;

      final isAuth = authState.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;
      final isPreAuth = loc.startsWith('/login') || loc.startsWith('/register');
      final isOnboarding = loc.startsWith('/username') || loc.startsWith('/location');

      if (!isAuth) {
        return isPreAuth ? null : '/login';
      }

      final hasUsername = (authState.user?.username ?? '').isNotEmpty;

      if (!hasUsername) {
        return isOnboarding ? null : '/username';
      }

      return (isPreAuth || loc.startsWith('/username')) ? '/map' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/username', builder: (_, __) => const UsernameScreen()),
      GoRoute(path: '/location', builder: (_, __) => const LocationPermissionScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ranks', builder: (_, __) => const TierListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/shop/:placeId',
        builder: (_, state) => ShopProfileScreen(placeId: state.pathParameters['placeId']!),
      ),
      GoRoute(
        path: '/rate/:placeId',
        builder: (_, state) => RateDrinkScreen(
          placeId: state.pathParameters['placeId']!,
          drinkId: state.uri.queryParameters['drinkId'],
        ),
      ),
      GoRoute(path: '/add-friends', builder: (_, __) => const AddFriendsScreen()),
      GoRoute(
        path: '/friend-profile/:uid',
        builder: (_, state) => FriendProfileScreen(friendUid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/friend-map/:uid',
        builder: (_, state) => FriendMapScreen(friendUid: state.pathParameters['uid']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );

  ref.listen(authProvider, (_, __) => router.refresh());

  return router;
});
