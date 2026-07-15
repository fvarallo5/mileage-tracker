import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_sheet.dart';
import 'screens/track_screen.dart';
import 'screens/trips_screen.dart';
import 'services/api_service.dart';
import 'services/voice_command_service.dart';
import 'theme/app_theme.dart';
import 'widgets/summary_strip.dart';

void main() {
  runApp(const MileageTrackerApp());
}

class MileageTrackerApp extends StatelessWidget {
  const MileageTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(ApiService())..initialize(),
      child: MaterialApp(
        title: 'Mileage Tracker',
        theme: buildAppTheme(),
        home: const HomeShell(),
        debugShowCheckedModeBanner: false,
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
  int _index = 0;
  VoiceCommandService? _voiceCommands;

  static const _screens = [
    TrackScreen(),
    TripsScreen(),
    ReportsScreen(),
  ];

  static const _labels = ['Track', 'Trips', 'Reports'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupVoiceCommands());
  }

  Future<void> _setupVoiceCommands() async {
    final state = context.read<AppState>();
    _voiceCommands = VoiceCommandService(
      onStartTrip: state.startTrackingFromVoice,
      onStopTrip: state.stopTrackingFromVoice,
    );
    _voiceCommands!.lastMessage.addListener(_onVoiceMessage);
    await _voiceCommands!.initialize();
  }

  void _onVoiceMessage() {
    final message = _voiceCommands?.lastMessage.value;
    if (message == null || !mounted) return;
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _voiceCommands?.lastMessage.value = null;
  }

  @override
  void dispose() {
    _voiceCommands?.lastMessage.removeListener(_onVoiceMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDark],
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: const Icon(Icons.route, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mileage Tracker', style: Theme.of(context).textTheme.titleLarge),
                            Text(
                              _labels[_index],
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      _ConnectionPill(connected: state.connected),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => showSettingsSheet(context),
                        icon: const Icon(Icons.tune_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_index == 0)
                  SummaryStrip(
                    weekly: state.summary?.weekly,
                    monthly: state.summary?.monthly,
                    annual: state.summary?.annual,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.gps_fixed_outlined),
                  selectedIcon: Icon(Icons.gps_fixed),
                  label: 'Track',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Trips',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Reports',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool connected;

  const _ConnectionPill({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (connected ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (connected ? AppColors.green : AppColors.red).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Live' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: connected ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}