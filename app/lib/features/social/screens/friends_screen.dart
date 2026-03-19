import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/social/widgets/activity_tab.dart';
import 'package:bobatier/features/social/widgets/want_to_try_tab.dart';
import 'package:bobatier/features/social/widgets/maps_tab.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendCount = ref.watch(friendsProvider).value?.length ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Friends', style: Theme.of(context).textTheme.headlineMedium),
                      Text('$friendCount friends', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                    GestureDetector(
                      onTap: () => context.push('/add-friends'),
                      child: Container(
                        width: 32, height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                        child: const Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary, indicatorWeight: 2.5,
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: [Tab(text: 'Activity'), Tab(text: 'Want to try'), Tab(text: 'Maps')],
              ),
              const Expanded(child: TabBarView(children: [ActivityTab(), WantToTryTab(), MapsTab()])),
            ],
          ),
        ),
      ),
    );
  }
}
