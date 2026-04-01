import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/navigation_contracts.dart';
import 'package:flutter_starter/core/routing/adapters/go_router_navigator_adapter.dart';
import 'package:flutter_starter/core/routing/app_router.dart';

/// Navigation contract provider.
final appNavigatorProvider = Provider<AppNavigator>((ref) {
  final router = ref.watch(goRouterProvider);
  return GoRouterNavigatorAdapter(router);
});
