import 'package:festivalbuddy/main.dart';
import 'package:festivalbuddy/models/festival_models.dart';
import 'package:festivalbuddy/services/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Guest launches with Discover, Tickets, More; Profile is in top app bar; Community appears for signed-in Visitor',
      (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(FestivalBuddyApp(appState: appState));

    // In guest mode, Community tab is NOT visible, Profile is in top bar tooltip
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.byTooltip('Profile & Security'), findsOneWidget);
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

  test('Organizer account and event approval workflow: pending until approved, deleted on reject', () {
    final appState = AppState();

    // 1. Register new organizer -> starts in Pending Approval
    appState.completeOrganizerRegistration(
      authMethod: 'Email (OTP)',
      companyName: 'Test Events B.V.',
      email: 'test@events.nl',
      phone: '+31 6 12345678',
      businessAddress: 'Eindhoven',
      kvkNumber: '12345678',
      vatNumber: 'NL123456789B01',
      govIdType: 'Dutch / EU Passport',
      govIdDocumentNumber: 'PASS1234',
      govIdFileName: 'scan.pdf',
    );
    expect(appState.isCurrentOrganizerApproved, isFalse);

    // 2. Admin approves organizer -> now approved
    appState.setOrganizerApproval('test@events.nl', approved: true);
    expect(appState.isCurrentOrganizerApproved, isTrue);

    // 3. Organizer publishes event -> starts in pendingFestivals
    appState.createFestivalListing(
      name: 'Test Festival',
      tagline: 'Sustainable vibes',
      dates: '10 Aug',
      city: 'Eindhoven',
      venueAddress: 'Strijp-S',
      distanceKm: 5,
      priceEur: 50,
      genres: ['Electronic & Techno'],
      howToGetThere: 'Train',
      publicTransportInfo: 'NS',
      festivalTransportOffer: 'Shuttle',
      ecoCommitments: const EcoCommitments(
        freeDrinkingWater: true,
        firstAidAndQuietZone: true,
        publicTransportIncluded: true,
        bicycleParking: true,
        reusableCupsOnly: true,
        recyclingStations: true,
        renewableEnergy: true,
        safeSpaceStewards: true,
        localEcoPartners: true,
      ),
    );
    final pendingEvent = appState.pendingFestivals.firstWhere((f) => f.name == 'Test Festival');
    expect(appState.approvedFestivals.any((f) => f.id == pendingEvent.id), isFalse);

    // 4. Admin approves event -> moves to approvedFestivals
    appState.approveFestival(pendingEvent.id);
    expect(appState.approvedFestivals.any((f) => f.id == pendingEvent.id), isTrue);

    // 5. Rejecting/deleting removes it completely
    appState.deleteFestival(pendingEvent.id);
    expect(appState.allFestivals.any((f) => f.id == pendingEvent.id), isFalse);
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
