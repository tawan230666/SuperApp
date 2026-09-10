import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const appPaths = [
  '/dashboard',
  '/trades',
  '/profit-router',
  '/long-term',
  '/assistant',
  '/bot',
  '/risk-analytics',
  '/settings',
  '/bot/strategies',
  '/bot/backtest',
];

class CapitalRouteParser extends RouteInformationParser<String> {
  const CapitalRouteParser();
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(
        routeInformation.uri.path == '/'
            ? '/dashboard'
            : routeInformation.uri.path,
      );
  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri(path: configuration));
}

class CapitalRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  CapitalRouter(this.builder);
  final Widget Function(String path, ValueChanged<String> navigate) builder;
  String _path = '/dashboard';
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  String get currentConfiguration => _path;
  void navigate(String path) {
    if (_path == path) return;
    _path = path;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _path = configuration;
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('workspace'),
        child: builder(_path, navigate),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}
