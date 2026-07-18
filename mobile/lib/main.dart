import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'providers/app_state.dart';
import 'providers/auth_state.dart';
import 'screens/auth_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_sheet.dart';
import 'screens/track_screen.dart';
import 'screens/trips_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
import 'services/voice_command_service.dart';
import 'theme/app_theme.dart';
import 'widgets/summary_strip.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  final themeService = ThemeService();
  await themeService.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(AuthService())..init()),
        ChangeNotifierProvider.value(value: themeService),
      ],
      child: const TrekTrackApp(),
    ),
  );
}

/// App root. [MileageTrackerApp] kept as alias for existing tests.
class TrekTrackApp extends StatelessWidget {
  const TrekTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeService>().mode;

    return MaterialApp(
      title: AppConfig.appName,
      theme: buildLightAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

@Deprecated('Use TrekTrackApp')
typedef MileageTrackerApp = TrekTrackApp;

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const _ConfigErrorScreen();
    }

    final auth = context.watch<AuthState>();
    if (auth.loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.isSignedIn) {
      return const AuthScreen();
    }
    return ChangeNotifierProvider(
      key: ValueKey(auth.userId),
      create: (_) => AppState(SupabaseService())..initialize(),
      child: const HomeShell(),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase not configured.\nRebuild with SUPABASE_URL and SUPABASE_ANON_KEY.',
            textAlign: TextAlign.center,
          ),
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
  int _index = 0;
  VoiceCommandService? _voiceCommands;
  AppState? _appState;

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
    _appState = state;
    _voiceCommands = VoiceCommandService(
      onStartTrip: state.startTrackingFromVoice,
      onStopTrip: state.stopTrackingFromVoice,
    );
    _voiceCommands!.lastMessage.addListener(_onVoiceMessage);
    await _voiceCommands!.initialize();

    // Lock-screen notification actions surface the same feedback as voice.
    state.lockScreen.lastMessage.addListener(_onLockScreenMessage);
  }

  void _onVoiceMessage() {
    final message = _voiceCommands?.lastMessage.value;
    if (message == null || !mounted) return;
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _voiceCommands?.lastMessage.value = null;
  }

  void _onLockScreenMessage() {
    final message = _appState?.lockScreen.lastMessage.value;
    if (message == null || !mounted) return;
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _appState?.lockScreen.lastMessage.value = null;
  }

  @override
  void dispose() {
    _voiceCommands?.lastMessage.removeListener(_onVoiceMessage);
    _appState?.lockScreen.lastMessage.removeListener(_onLockScreenMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    0,
                  ),
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
                            Text(
                              AppConfig.appName,
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              _labels[_index],
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
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
                          backgroundColor: scheme.surface,
                          side: BorderSide(color: scheme.outline),
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outline)),
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
