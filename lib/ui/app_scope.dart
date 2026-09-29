import 'package:flutter/widgets.dart';

import '../services/night_store.dart';
import '../services/settings.dart';
import '../services/tracking_controller.dart';

/// Makes the app's shared objects available to every screen.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.store,
    required this.tracking,
    required super.child,
  });

  final Settings settings;
  final NightStore store;
  final TrackingController tracking;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      settings != old.settings || store != old.store || tracking != old.tracking;
}
