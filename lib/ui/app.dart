import 'package:flutter/material.dart';

import '../services/night_store.dart';
import '../services/settings.dart';
import '../services/tracking_controller.dart';
import 'app_scope.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tonight_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/trends_screen.dart';
import 'theme.dart';

class AiSleepApp extends StatelessWidget {
  const AiSleepApp({
    super.key,
    required this.settings,
    required this.store,
    required this.tracking,
  });

  final Settings settings;
  final NightStore store;
  final TrackingController tracking;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      store: store,
      tracking: tracking,
      child: MaterialApp(
        title: 'Sleep Coach',
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: ListenableBuilder(
          listenable: tracking,
          // While a night is running, the tracking screen takes over.
          builder: (context, _) => tracking.state == TrackingState.idle
              ? const HomeShell()
              : const TrackingScreen(),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _pages = [TonightScreen(), HistoryScreen(), TrendsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bedtime_outlined), label: 'Tonight'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
