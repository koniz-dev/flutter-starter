import 'package:flutter_starter/core/routing/app_routes.dart';

/// [path] (`/login` or `/register`) carrying [redirect] as its `redirect`
/// query parameter, so moving between the two auth screens keeps the deep
/// link the router guard parked there.
///
/// Without this a new user who opened a shared link and chose "Register"
/// signed up and landed on `/`. [redirect] is
/// passed through untouched: the guard's `_destinationAfterAuth` is what
/// rejects an off-site or looping target, and it runs on whichever auth route
/// the user finishes on.
String authLocationKeepingRedirect(String path, String? redirect) {
  if (redirect == null || redirect.isEmpty) return path;
  return Uri(
    path: path,
    queryParameters: {RouteQueryParams.redirect: redirect},
  ).toString();
}
