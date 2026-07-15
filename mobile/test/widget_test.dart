import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_tracker/main.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const MileageTrackerApp());
    expect(find.text('Mileage Tracker'), findsOneWidget);
  });
}