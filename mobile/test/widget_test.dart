import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/main.dart';
import 'package:mileage_tracker/services/theme_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: const TrekTrackApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    // Without Supabase env in tests, gate shows config help (or auth/loading).
    expect(
      find.textContaining('Supabase').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('TrekTrack').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
