import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mileage_tracker/config/supabase_config.dart';
import 'package:mileage_tracker/main.dart' show MileageTrackerApp;
import 'package:provider/provider.dart';
import 'package:mileage_tracker/providers/auth_state.dart';
import 'package:mileage_tracker/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

const testEmail = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'mileage.sim.test.1784164596@gmail.com',
);
const testPassword = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: 'TestPass123!',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in on simulator reaches main app', (tester) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    if (!SupabaseConfig.isConfigured) {
      fail('Supabase not configured — pass SUPABASE_URL and SUPABASE_ANON_KEY');
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    await Supabase.instance.client.auth.signOut();

    final authState = AuthState(AuthService());
    await authState.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authState,
        child: const MileageTrackerApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('Sign In'), findsWidgets);

    await tester.enterText(find.byKey(const Key('auth_email')), testEmail);
    await tester.enterText(find.byKey(const Key('auth_password')), testPassword);
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Sign-up test trip'), findsOneWidget);
  });
}