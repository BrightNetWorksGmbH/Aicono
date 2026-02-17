// Re-export go_router but replace the BuildContext extension so that [pop]
// navigates to '/' when the stack is empty (e.g. after a full page refresh on web).
library safe_go_router;

export 'package:go_router/go_router.dart' hide GoRouterHelper;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Same as go_router's [GoRouterHelper] but [pop] goes to '/' when stack is empty.
extension GoRouterHelper on BuildContext {
  String namedLocation(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    String? fragment,
  }) =>
      GoRouter.of(this).namedLocation(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        fragment: fragment,
      );

  void go(String location, {Object? extra}) =>
      GoRouter.of(this).go(location, extra: extra);

  void goNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
    String? fragment,
  }) =>
      GoRouter.of(this).goNamed(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
        fragment: fragment,
      );

  Future<T?> push<T extends Object?>(String location, {Object? extra}) =>
      GoRouter.of(this).push<T>(location, extra: extra);

  Future<T?> pushNamed<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) =>
      GoRouter.of(this).pushNamed<T>(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );

  bool canPop() => GoRouter.of(this).canPop();

  /// Pops the top route, or goes to '/' when the stack is empty (e.g. after refresh).
  void pop<T extends Object?>([T? result]) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop(result);
    } else {
      router.go('/');
    }
  }

  void pushReplacement(String location, {Object? extra}) =>
      GoRouter.of(this).pushReplacement(location, extra: extra);

  void pushReplacementNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) =>
      GoRouter.of(this).pushReplacementNamed(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );

  void replace(String location, {Object? extra}) =>
      GoRouter.of(this).replace<Object?>(location, extra: extra);

  void replaceNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) =>
      GoRouter.of(this).replaceNamed<Object?>(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );
}
