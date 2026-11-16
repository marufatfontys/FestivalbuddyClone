import 'package:festivalbuddy/main.dart';
import 'package:festivalbuddy/models/festival_models.dart';
import 'package:festivalbuddy/services/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Guest launches with Discover, Tickets, Profile, More; Community appears only for signed-in Visitor',
      (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(FestivalBuddyApp(appState: appState));

    // In guest mode, Community tab is NOT visible
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Community'), findsNothing);

    // Sign in as visitor -> Community tab appears
    appState.completeVisitorSignIn(method: 'Google');
    await tester.pumpAndSettle();
    expect(find.text('Community'), findsOneWidget);

    appState.stopAiIngestionTimer();
  });

  test('Auto-detect location pin requires device location enabled', () async {
    final appState = AppState();
    final fest = appState.approvedFestivals.first;

    appState.setDeviceLocationEnabled(false);
    final blocked = await appState.autoDetectAndPinSpot(
      festival: fest,
      type: PersonalPinType.car,
    );
    expect(blocked, isNull);

    // Enable location -> auto-detect pin succeeds
    appState.setDeviceLocationEnabled(true);
    final pin = await appState.autoDetectAndPinSpot(
      festival: fest,
      type: PersonalPinType.car,
    );
    expect(pin, isNotNull);
    expect(pin!.zoneLabel, contains('GPS'));
    expect(
      appState
          .getPersonalPins(fest.id)
          .any((p) => p.type == PersonalPinType.car),
      isTrue,
    );

    // Unpin works
    appState.removePersonalPin(festivalId: fest.id, type: PersonalPinType.car);
    expect(
      appState
          .getPersonalPins(fest.id)
          .any((p) => p.type == PersonalPinType.car),
      isFalse,
    );
  });

  test('Unique username generated on visitor sign in', () {
    final appState = AppState();
    appState.completeVisitorSignIn(
      method: 'Email (OTP)',
      email: 'john.doe@gmail.com',
      name: 'John Doe',
    );
    expect(appState.visitorUsername.startsWith('@'), isTrue);
    expect(appState.visitorUsername, contains('john_doe'));
    appState.stopAiIngestionTimer();
  });

  test('AI Ingested events review queue: approve publishes to discover, reject removes', () {
    final appState = AppState();
    
    // Check pending AI crawled events
    final pendingAi = appState.allFestivals.where((f) => f.isAiIngested && !f.isApprovedByAdmin).toList();
    expect(pendingAi.isNotEmpty, isTrue);

    final targetFest = pendingAi.first;
    expect(appState.approvedFestivals.any((f) => f.id == targetFest.id), isFalse);

    // Approve event
    appState.approveFestival(targetFest.id);
    expect(appState.approvedFestivals.any((f) => f.id == targetFest.id), isTrue);

    // Reject remaining event
    final remainingPending = appState.allFestivals.where((f) => f.isAiIngested && !f.isApprovedByAdmin).toList();
    if (remainingPending.isNotEmpty) {
      final rejectTarget = remainingPending.first;
      appState.removeFestivalListing(rejectTarget.id);
      expect(appState.allFestivals.any((f) => f.id == rejectTarget.id), isFalse);
    }

    appState.stopAiIngestionTimer();
  });

  testWidgets('Searching artist name in lineups filters and displays festival on Discover', (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(FestivalBuddyApp(appState: appState));

    // GreenPulse Open Air has artist "Aurora Pulse (Live)" in its lineup
    // Enter artist name into the search bar
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'Aurora Pulse');
    await tester.pumpAndSettle();

    // Verify GreenPulse appears and displays the matched artist
    expect(find.text('GreenPulse Open Air'), findsOneWidget);
    expect(find.textContaining('Aurora Pulse (Live)'), findsOneWidget);

    // Verify non-matching festival like "Horizon Beats Festival" is filtered out
    expect(find.text('Horizon Beats Festival'), findsNothing);

    appState.stopAiIngestionTimer();
  });
}
