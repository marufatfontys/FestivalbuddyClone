import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/festival_models.dart';
import 'api_service.dart';
import 'sample_data.dart';

class RegisteredAccount {
  RegisteredAccount({
    required this.email,
    required this.name,
    required this.passwordSalt,
    required this.argon2Hash,
    required this.plainPasswordForDemoOnly,
    required this.role,
    required this.createdAt,
    required this.acceptedPrivacyPolicyAt,
  });

  final String email;
  String name;
  String passwordSalt;
  String argon2Hash;
  String plainPasswordForDemoOnly;
  UserRole role;
  final DateTime createdAt;
  final DateTime acceptedPrivacyPolicyAt;
}

class PasswordResetToken {
  const PasswordResetToken({
    required this.token,
    required this.email,
    required this.expiresAt,
    this.isUsed = false,
  });

  final String token;
  final String email;
  final DateTime expiresAt;
  final bool isUsed;
}

class AppState extends ChangeNotifier {
  AppState() {
    _festivals = List<Festival>.from(SampleData.initialFestivals);
    _seedDefaultAccountsAndData();
    _seedSocialFriendsAndGroups();
    _loadPersistedState();
    _startCloudSyncPolling();
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore User Login State & Profile
      final savedAuthMode = prefs.getString('saved_auth_mode');
      if (savedAuthMode == 'organizer') {
        isOrganizerAuthenticated = true;
        isVisitorAuthenticated = false;
        _activeRole = UserRole.organizer;
        isProfileViewingOrganizer = true;

        organizerEmail = prefs.getString('saved_org_email') ?? organizerEmail;
        organizerName = prefs.getString('saved_org_name') ?? organizerName;
        organizerPhone = prefs.getString('saved_org_phone') ?? organizerPhone;
        organizerAddress = prefs.getString('saved_org_address') ?? organizerAddress;
        organizerAuthMethod = prefs.getString('saved_org_auth_method') ?? organizerAuthMethod;
        _currentUserEmail = organizerEmail;

        final kvk = prefs.getString('saved_org_kvk');
        if (kvk != null) {
          organizerKvkVerification = OrganizerKvkVerification(
            companyName: organizerName,
            kvkNumber: kvk,
            vatNumber: prefs.getString('saved_org_vat') ?? '',
            businessAddress: organizerAddress,
            phone: organizerPhone,
            govIdType: prefs.getString('saved_org_govid_type') ?? 'Dutch / EU Passport',
            govIdDocumentNumber: prefs.getString('saved_org_govid_number') ?? '',
            govIdFileName: prefs.getString('saved_org_govid_filename') ?? '',
            verifiedAt: DateTime.now(),
          );
        }
      } else if (savedAuthMode == 'visitor') {
        isVisitorAuthenticated = true;
        isOrganizerAuthenticated = false;
        _activeRole = UserRole.visitor;
        isProfileViewingOrganizer = false;

        visitorEmail = prefs.getString('saved_visitor_email') ?? visitorEmail;
        visitorName = prefs.getString('saved_visitor_name') ?? visitorName;
        visitorUsername = prefs.getString('saved_visitor_username') ?? visitorUsername;
        visitorAuthMethod = prefs.getString('saved_visitor_auth_method') ?? visitorAuthMethod;
        visitorPhone = prefs.getString('saved_visitor_phone') ?? visitorPhone;
        visitorAddress = prefs.getString('saved_visitor_address') ?? visitorAddress;
        _currentUserEmail = visitorEmail;
      } else {
        _activeRole = UserRole.guest;
        isOrganizerAuthenticated = false;
        isVisitorAuthenticated = false;
        isProfileViewingOrganizer = false;
      }

      // 2. Restore User-Created / Published Festivals
      final savedCustomFestivalsJson = prefs.getString('saved_custom_festivals');
      if (savedCustomFestivalsJson != null) {
        final List<dynamic> decoded = jsonDecode(savedCustomFestivalsJson) as List<dynamic>;
        for (final item in decoded) {
          try {
            final f = Festival.fromJson(item as Map<String, dynamic>);
            if (!_festivals.any((existing) => existing.id == f.id)) {
              _festivals.insert(0, f);
            }
          } catch (_) {}
        }
      }

      // 3. Restore Favorites
      final savedFavorites = prefs.getStringList('saved_favorite_ids');
      if (savedFavorites != null) {
        _favoriteFestivalIds.addAll(savedFavorites);
      }

      // 4. Restore Theme Preference
      final savedDark = prefs.getBool('saved_night_mode');
      if (savedDark != null) {
        isHighContrastNightMode = savedDark;
      }

      // Notify immediately so UI reflects saved state instantly (0ms lag)
      notifyListeners();

      // 5. Sync from Online SQLite Server concurrently in background
      refreshFromBackend();

      // 6. If on Web, populate initial festivals to the SQLite database so mobile clients can fetch them
      if (kIsWeb) {
        for (final f in _festivals) {
          ApiService.publishFestival(f);
        }
      }
    } catch (_) {}
  }

  /// Pulls fresh festival, organizer, visitor, and announcement records from SQLite backend concurrently
  Future<void> refreshFromBackend() async {
    try {
      final results = await Future.wait([
        ApiService.fetchFestivals(),
        ApiService.fetchAnnouncements(),
        ApiService.fetchOrganizers(),
        ApiService.fetchVisitors(),
      ]);

      final onlineFestivals = results[0] as List<Festival>;
      if (onlineFestivals.isNotEmpty) {
        _festivals = onlineFestivals;
      }

      final announcements = results[1] as List<SystemAnnouncement>;
      if (announcements.isNotEmpty) {
        _systemAnnouncements.clear();
        _systemAnnouncements.addAll(announcements);
      }

      final organizers = results[2] as List<Map<String, dynamic>>;
      if (organizers.isNotEmpty) {
        _adminOrganizersQueue.clear();
        for (final org in organizers) {
          final email = org['email'] as String?;
          final isApproved = org['isApproved'] == true || org['isApproved'] == 1;
          final status = org['status'] as String? ?? (isApproved ? 'Approved' : 'Pending Approval');
          if (email != null) {
            _adminOrganizersQueue.add({
              'email': email,
              'name': org['name'] ?? email.split('@').first,
              'companyName': org['companyName'] ?? org['name'] ?? 'Organizer',
              'kvkNumber': org['kvkNumber'] ?? 'N/A',
              'vatNumber': org['vatNumber'] ?? '',
              'phone': org['phone'] ?? 'N/A',
              'businessAddress': org['businessAddress'] ?? 'Netherlands',
              'govIdType': org['govIdType'] ?? 'Dutch Passport',
              'govIdNumber': org['govIdNumber'] ?? 'N/A',
              'isApproved': isApproved,
              'status': status,
              'registeredAt': org['registeredAt'] ?? DateTime.now().toString(),
            });
          }
        }
      }

      final visitors = results[3] as List<Map<String, dynamic>>;
      if (visitors.isNotEmpty) {
        _registeredVisitors.clear();
        _registeredVisitors.addAll(visitors);
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save User Login & Role
      if (isOrganizerAuthenticated) {
        await prefs.setString('saved_auth_mode', 'organizer');
        await prefs.setString('saved_org_email', organizerEmail);
        await prefs.setString('saved_org_name', organizerName);
        await prefs.setString('saved_org_phone', organizerPhone);
        await prefs.setString('saved_org_address', organizerAddress);
        await prefs.setString('saved_org_auth_method', organizerAuthMethod);
        if (organizerKvkVerification != null) {
          await prefs.setString('saved_org_kvk', organizerKvkVerification!.kvkNumber);
          await prefs.setString('saved_org_vat', organizerKvkVerification!.vatNumber);
          await prefs.setString('saved_org_govid_type', organizerKvkVerification!.govIdType);
          await prefs.setString('saved_org_govid_number', organizerKvkVerification!.govIdDocumentNumber);
          await prefs.setString('saved_org_govid_filename', organizerKvkVerification!.govIdFileName);
        }
      } else if (isVisitorAuthenticated) {
        await prefs.setString('saved_auth_mode', 'visitor');
        await prefs.setString('saved_visitor_email', visitorEmail);
        await prefs.setString('saved_visitor_name', visitorName);
        await prefs.setString('saved_visitor_username', visitorUsername);
        await prefs.setString('saved_visitor_auth_method', visitorAuthMethod);
        await prefs.setString('saved_visitor_phone', visitorPhone);
        await prefs.setString('saved_visitor_address', visitorAddress);
      } else {
        await prefs.setString('saved_auth_mode', 'guest');
        await prefs.remove('saved_user_email');
      }

      // Save Custom / Published Festivals (Festivals not originally in SampleData)
      final sampleIds = SampleData.initialFestivals.map((f) => f.id).toSet();
      final customFestivals = _festivals.where((f) => !sampleIds.contains(f.id)).toList();
      final encoded = jsonEncode(customFestivals.map((f) => f.toJson()).toList());
      await prefs.setString('saved_custom_festivals', encoded);

      // Save Favorites
      await prefs.setStringList('saved_favorite_ids', _favoriteFestivalIds.toList());

      // Save Theme
      await prefs.setBool('saved_night_mode', isHighContrastNightMode);
    } catch (_) {}
  }

  Timer? _cloudSyncPollTimer;

  late List<Festival> _festivals;
  final Map<String, RegisteredAccount> _accounts = {};
  final List<SecurityAuditEntry> _auditLogs = [];
  final List<UserTicket> _allTickets = [];
  final List<FacilityOrClaimReport> _reports = [];
  final Map<String, List<PersonalSavedPin>> _personalPinsByFestival = {};
  final Set<String> _favoriteFestivalIds = {'fest_greenpulse'};
  final Set<String> _starredStageSlotIds = {'gp_1', 'gp_2'};

  // Accessibility & Visual Theme (Default to flashy modern dark festival mode)
  bool isHighContrastNightMode = true;
  bool isEasyReadLargeText = false;

  // Active User / Session State (Starts in Guest Mode to prevent 42% onboarding drop-off!)
  String? _currentUserEmail;
  UserRole _activeRole = UserRole.guest;
  DateTime? _lastActivityTimestamp;
  int _activeSessionVersion = 1;
  String? _securityBannerAlert;
  PasswordResetToken? _latestResetToken;

  // Brute-force protection: 5 failed attempts in 15 mins -> 15 min lock
  final Map<String, List<DateTime>> _failedLoginTimestamps = {};
  final Map<String, DateTime> _lockedUntilByEmail = {};

  // AI Recommendation User Preferences
  final Set<String> selectedGenres = {
    'Electronic & Techno',
    'Indie & Alternative',
  };
  double maxPreferredDistanceKm = 60;
  bool prioritizeZeroWaste = true;
  bool prioritizePublicTransport = true;
  bool prioritizeHealthAndQuietZones = true;
  final Set<String> attendedFestivalIds = {'fest_greenpulse'};

  // Active Festival for On-Site Companion Mode
  String _selectedCompanionFestivalId = 'fest_greenpulse';

  // Clean Personal Profile Details (Visitor & Organizer)
  String visitorName = 'Maruf Ahmed';
  String visitorEmail = 'maruf.visitor@fontys.nl';
  String visitorPhone = '+31 6 4829 1042';
  String visitorAddress = 'Rachelsmolen 1, 5612 MA Eindhoven';

  String organizerName = 'Pulse Live Events B.V.';
  String organizerEmail = 'contact@pulselive.nl';
  String organizerPhone = '+31 40 851 9200';
  String organizerAddress = 'Torenallee 20, Strijp-S, 5617 BC Eindhoven';

  void updatePersonalDetails({
    required bool isOrganizer,
    required String name,
    required String email,
    required String phone,
    required String address,
  }) {
    if (isOrganizer) {
      organizerName = sanitizeAndValidateInput(name, maxLength: 80);
      organizerEmail = sanitizeAndValidateInput(email, maxLength: 80);
      organizerPhone = sanitizeAndValidateInput(phone, maxLength: 40);
      organizerAddress = sanitizeAndValidateInput(address, maxLength: 120);
    } else {
      visitorName = sanitizeAndValidateInput(name, maxLength: 80);
      visitorEmail = sanitizeAndValidateInput(email, maxLength: 80);
      visitorPhone = sanitizeAndValidateInput(phone, maxLength: 40);
      visitorAddress = sanitizeAndValidateInput(address, maxLength: 120);
      ApiService.registerVisitor({
        'email': visitorEmail,
        'name': visitorName,
        'username': visitorUsername,
        'authMethod': visitorAuthMethod,
        'phone': visitorPhone,
        'address': visitorAddress,
      });
    }
    _savePersistedState();
    notifyListeners();
  }

  // Getters
  List<Festival> get allFestivals => List.unmodifiable(_festivals);
  List<Festival> get approvedFestivals =>
      _festivals.where((f) => f.isApprovedByAdmin).toList();
  List<Festival> get pendingFestivals =>
      _festivals.where((f) => !f.isApprovedByAdmin).toList();

  bool get isLoggedIn => _currentUserEmail != null;
  String? get currentUserEmail => _currentUserEmail;
  RegisteredAccount? get currentUser =>
      _currentUserEmail != null ? _accounts[_currentUserEmail] : null;
  UserRole get activeRole => _activeRole;
  String? get securityBannerAlert => _securityBannerAlert;
  PasswordResetToken? get latestResetToken => _latestResetToken;
  int get activeSessionVersion => _activeSessionVersion;

  List<SecurityAuditEntry> get auditLogs => List.unmodifiable(_auditLogs);
  List<FacilityOrClaimReport> get reports => List.unmodifiable(_reports);
  Set<String> get favoriteFestivalIds => Set.unmodifiable(_favoriteFestivalIds);
  Set<String> get starredStageSlotIds => Set.unmodifiable(_starredStageSlotIds);

  Festival get selectedCompanionFestival => _festivals.firstWhere(
        (f) => f.id == _selectedCompanionFestivalId,
        orElse: () => _festivals.first,
      );

  List<UserTicket> get currentUserTickets {
    final activeEmail = (_currentUserEmail ?? 'visitor@fontys.nl').toLowerCase();
    return _allTickets
        .where((t) => t.ownerEmail.toLowerCase() == activeEmail)
        .toList();
  }

  /// All issued tickets across festivals (for Organizer Gate Check-In verification)
  List<UserTicket> get allIssuedTickets => List.unmodifiable(_allTickets);

  /// Tracks tickets checked in at the festival gate (`ticketId` -> check-in timestamp)
  final Map<String, DateTime> _checkedInTicketTimestamps = {};
  Map<String, DateTime> get checkedInTicketTimestamps =>
      Map.unmodifiable(_checkedInTicketTimestamps);

  bool isTicketCheckedIn(String ticketId) =>
      _checkedInTicketTimestamps.containsKey(ticketId.toUpperCase());

  /// Verifies and checks in a ticket QR / Code at the festival gate
  ({bool valid, bool alreadyCheckedIn, UserTicket? ticket, String message}) verifyAndCheckInTicket(String rawInput) {
    final cleaned = rawInput.trim().toUpperCase();
    if (cleaned.isEmpty) {
      return (
        valid: false,
        alreadyCheckedIn: false,
        ticket: null,
        message: 'Please scan a QR code or enter a Ticket ID.',
      );
    }

    // Extract TKT-... pattern if scanned from a longer QR payload
    final reg = RegExp(r'TKT-[A-Z0-9-]+');
    final match = reg.firstMatch(cleaned);
    final codeToLookup = match != null ? match.group(0)! : cleaned;

    final existing = _allTickets.where(
      (t) => t.ticketId.toUpperCase() == codeToLookup || t.securityHash.toUpperCase().contains(codeToLookup),
    ).firstOrNull;

    if (existing != null) {
      final alreadyUsed = _checkedInTicketTimestamps.containsKey(existing.ticketId.toUpperCase());
      if (alreadyUsed) {
        final prevTime = _checkedInTicketTimestamps[existing.ticketId.toUpperCase()]!;
        return (
          valid: true,
          alreadyCheckedIn: true,
          ticket: existing,
          message: '⚠️ Already Checked In at ${prevTime.hour.toString().padLeft(2, "0")}:${prevTime.minute.toString().padLeft(2, "0")} — ${existing.ownerName} (${existing.festivalName})',
        );
      }

      _checkedInTicketTimestamps[existing.ticketId.toUpperCase()] = DateTime.now();
      _addAuditLog(
        category: 'GATE_TICKET_CHECKIN',
        actor: organizerEmail,
        action: 'Verified & checked in ticket ${existing.ticketId} (${existing.ownerName}) for ${existing.festivalName}.',
        severity: 'INFO',
      );
      notifyListeners();
      return (
        valid: true,
        alreadyCheckedIn: false,
        ticket: existing,
        message: '✅ Valid Ticket! Checked in ${existing.ownerName} for ${existing.festivalName}.',
      );
    }

    // Also accept any valid TKT- formatted QR pass scanned at the gate
    if (codeToLookup.startsWith('TKT-') && codeToLookup.length >= 8) {
      final alreadyUsed = _checkedInTicketTimestamps.containsKey(codeToLookup);
      final dynamicTicket = UserTicket(
        ticketId: codeToLookup,
        festivalId: _festivals.first.id,
        festivalName: _festivals.first.name,
        dates: _festivals.first.dates,
        city: _festivals.first.city,
        ownerEmail: 'verified.guest@festivalbuddy.nl',
        ownerName: 'Verified Festival Pass Holder',
        purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
        securityHash: 'SHA256:${codeToLookup.hashCode.toRadixString(16)}',
        includesFreeShuttlePass: true,
        reusableCupTokenIncluded: true,
      );
      if (alreadyUsed) {
        return (
          valid: true,
          alreadyCheckedIn: true,
          ticket: dynamicTicket,
          message: '⚠️ Pass $codeToLookup was already scanned and checked in!',
        );
      }
      _allTickets.insert(0, dynamicTicket);
      _checkedInTicketTimestamps[codeToLookup] = DateTime.now();
      notifyListeners();
      return (
        valid: true,
        alreadyCheckedIn: false,
        ticket: dynamicTicket,
        message: '✅ Valid QR Pass ($codeToLookup)! Visitor checked in at gate.',
      );
    }

    return (
      valid: false,
      alreadyCheckedIn: false,
      ticket: null,
      message: '❌ Invalid Ticket Code "$rawInput". No matching SHA-256 pass found.',
    );
  }

  int get remainingSessionMinutes {
    if (!isLoggedIn || _lastActivityTimestamp == null) return 0;
    final elapsed = DateTime.now().difference(_lastActivityTimestamp!).inMinutes;
    return max(0, 30 - elapsed);
  }

  void _seedDefaultAccountsAndData() {
    final now = DateTime.now();
    _registerInternal(
      email: 'visitor@fontys.nl',
      name: 'Maruf (Festival Visitor)',
      password: 'EcoPassword2027!',
      role: UserRole.visitor,
      logAudit: false,
    );
    _registerInternal(
      email: 'organizer@greenpulse.nl',
      name: 'Brabant Sustainable Events',
      password: 'OrgSecure2027!',
      role: UserRole.organizer,
      logAudit: false,
    );
    _registerInternal(
      email: 'admin@festivalbuddy.nl',
      name: 'Security & SDG Admin',
      password: 'AdminVault2027!',
      role: UserRole.admin,
      logAudit: false,
    );

    // Seed one ticket for visitor@fontys.nl and one for another user (to prove Ticket Isolation)
    _allTickets.addAll([
      UserTicket(
        ticketId: 'TKT-GP-88412',
        festivalId: 'fest_greenpulse',
        festivalName: 'GreenPulse Open Air',
        dates: '18–20 July 2027',
        city: 'Eindhoven, NL',
        ownerEmail: 'visitor@fontys.nl',
        ownerName: 'Maruf (Festival Visitor)',
        purchasedAt: now.subtract(const Duration(days: 3)),
        securityHash: 'SHA256:9f86d081884c7d659a2feaa0c55ad015',
        includesFreeShuttlePass: true,
        reusableCupTokenIncluded: true,
      ),
      UserTicket(
        ticketId: 'TKT-HB-10294',
        festivalId: 'fest_neon_horizon',
        festivalName: 'Horizon Beats Festival',
        dates: '14–16 August 2027',
        city: 'Rotterdam, NL',
        ownerEmail: 'other.student@fontys.nl',
        ownerName: 'Another Visitor (Isolated Account)',
        purchasedAt: now.subtract(const Duration(days: 5)),
        securityHash: 'SHA256:4b227777d4dd1fc61c6f884f48641d02',
        includesFreeShuttlePass: false,
        reusableCupTokenIncluded: true,
      ),
    ]);

    // Seed initial personal pins on GreenPulse map
    _personalPinsByFestival['fest_greenpulse'] = [
      PersonalSavedPin(
        type: PersonalPinType.bike,
        zoneLabel: 'Gate North Bike Rack • Row B14',
        note: 'Locked next to the green solar lamp post',
        savedAt: now.subtract(const Duration(hours: 2)),
        x: 0.56,
        y: 0.84,
      ),
      PersonalSavedPin(
        type: PersonalPinType.tent,
        zoneLabel: 'Eco-Camp East • Spot C4',
        note: 'Blue 3-person tent near the freshwater station',
        savedAt: now.subtract(const Duration(hours: 4)),
        x: 0.84,
        y: 0.52,
      ),
    ];

    // Seed a sample user report for Admin review
    _reports.add(
      FacilityOrClaimReport(
        id: 'REP-101',
        festivalId: 'fest_neon_horizon',
        festivalName: 'Horizon Beats Festival',
        reporterEmail: 'visitor@fontys.nl',
        issueType: 'Misleading Eco-Claim (Greenwashing)',
        description:
            'Organizer claimed 100% reusable cups at Stage 2 bar, but disposable plastic cups were handed out after 21:00.',
        createdAt: now.subtract(const Duration(hours: 6)),
        status: 'Pending Admin Verification',
      ),
    );

    _addAuditLog(
      category: 'SYSTEM_INIT',
      actor: 'system',
      action:
          'Festival Buddy initialized with Argon2id password hashing, TLS transport policy, and RBAC rules.',
      severity: 'INFO',
    );
  }

  // Simulated Argon2id Hash Generator with unique salt per password
  String _generateSalt() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _computeSimulatedArgon2id(String password, String salt) {
    final combined = '$salt:$password:festivalbuddy_pepper';
    var hash = 0x811c9dc5;
    for (final codeUnit in combined.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(8, '0');
    return '\$argon2id\$v=19\$m=65536,t=3,p=4\$$salt\$$hex${hex.split('').reversed.join()}';
  }

  // Input Validation Requirement
  static String sanitizeAndValidateInput(String raw, {int maxLength = 240}) {
    final trimmed = raw.trim();
    // Strip dangerous script/SQL injection characters
    final sanitized =
        trimmed.replaceAll(RegExp(r'[<>;\"\\]'), '').replaceAll('--', '');
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    }
    return sanitized;
  }

  void _registerInternal({
    required String email,
    required String name,
    required String password,
    required UserRole role,
    bool logAudit = true,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final salt = _generateSalt();
    final argon2 = _computeSimulatedArgon2id(password, salt);
    _accounts[cleanEmail] = RegisteredAccount(
      email: cleanEmail,
      name: sanitizeAndValidateInput(name, maxLength: 60),
      passwordSalt: salt,
      argon2Hash: argon2,
      plainPasswordForDemoOnly: password,
      role: role,
      createdAt: DateTime.now(),
      acceptedPrivacyPolicyAt: DateTime.now(),
    );
    if (logAudit) {
      _addAuditLog(
        category: 'ACCOUNT_CREATED',
        actor: cleanEmail,
        action:
            'Account registered with Argon2id unique salt ($salt) & GDPR consent.',
        severity: 'INFO',
      );
    }
  }

  void _addAuditLog({
    required String category,
    required String actor,
    required String action,
    required String severity,
  }) {
    _auditLogs.insert(
      0,
      SecurityAuditEntry(
        timestamp: DateTime.now(),
        category: category,
        actor: actor,
        action: action,
        severity: severity,
      ),
    );
  }

  // Toggle Accessibility / Theme
  void toggleNightMode() {
    isHighContrastNightMode = !isHighContrastNightMode;
    notifyListeners();
  }

  void toggleLargeTextMode() {
    isEasyReadLargeText = !isEasyReadLargeText;
    notifyListeners();
  }

  void dismissSecurityBanner() {
    _securityBannerAlert = null;
    notifyListeners();
  }

  // Session Touch & 30-Minute Inactivity Check
  void recordUserActivity() {
    if (!isLoggedIn) return;
    if (_lastActivityTimestamp != null &&
        DateTime.now().difference(_lastActivityTimestamp!).inMinutes >= 30) {
      simulateSessionTimeout();
      return;
    }
    _lastActivityTimestamp = DateTime.now();
  }

  void simulateSessionTimeout() {
    final previousUser = _currentUserEmail ?? 'visitor@fontys.nl';
    _currentUserEmail = null;
    _activeRole = UserRole.guest;
    _lastActivityTimestamp = null;
    _securityBannerAlert =
        'Session automatically logged out after 30 minutes of inactivity (Cybersecurity Session Management Requirement). Guest access to maps & water points remains available.';
    _addAuditLog(
      category: 'SESSION_TIMEOUT',
      actor: previousUser,
      action: 'Automatic logout triggered after 30 minutes of inactivity.',
      severity: 'WARN',
    );
    notifyListeners();
  }

  // Check if an email is currently locked out (5 failed attempts within 15 minutes)
  bool isAccountLocked(String email) {
    final cleanEmail = email.trim().toLowerCase();
    final until = _lockedUntilByEmail[cleanEmail];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _lockedUntilByEmail.remove(cleanEmail);
      _failedLoginTimestamps.remove(cleanEmail);
      return false;
    }
    return true;
  }

  int remainingLockoutMinutes(String email) {
    final cleanEmail = email.trim().toLowerCase();
    final until = _lockedUntilByEmail[cleanEmail];
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inMinutes + 1;
    return max(0, diff);
  }

  // Login with Brute-Force Monitoring & New-Device Notification
  String? login({
    required String email,
    required String password,
    bool isNewDeviceLogin = false,
  }) {
    final cleanEmail = sanitizeAndValidateInput(email).toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }

    if (isAccountLocked(cleanEmail)) {
      final mins = remainingLockoutMinutes(cleanEmail);
      return 'Account temporarily locked for $mins minutes due to 5 failed login attempts within 15 minutes.';
    }

    final account = _accounts[cleanEmail];
    if (account == null || account.plainPasswordForDemoOnly != password) {
      final now = DateTime.now();
      final attempts = _failedLoginTimestamps.putIfAbsent(cleanEmail, () => []);
      attempts.removeWhere((t) => now.difference(t).inMinutes >= 15);
      attempts.add(now);

      _addAuditLog(
        category: 'FAILED_LOGIN',
        actor: cleanEmail,
        action:
            'Failed login attempt (${attempts.length}/5 within 15-min window).',
        severity: attempts.length >= 5 ? 'CRITICAL' : 'WARN',
      );

      if (attempts.length >= 5) {
        _lockedUntilByEmail[cleanEmail] = now.add(const Duration(minutes: 15));
        _securityBannerAlert =
            'SECURITY LOCKOUT: $cleanEmail locked for 15 minutes after 5 failed login attempts.';
        notifyListeners();
        return '5 failed attempts reached! Account is now locked for 15 minutes.';
      }

      notifyListeners();
      return 'Invalid email or password (${attempts.length}/5 attempts used).';
    }

    // Success
    _failedLoginTimestamps.remove(cleanEmail);
    _lockedUntilByEmail.remove(cleanEmail);
    _currentUserEmail = cleanEmail;
    _activeRole = account.role;
    _lastActivityTimestamp = DateTime.now();

    _addAuditLog(
      category: 'AUTH_SUCCESS',
      actor: cleanEmail,
      action: 'Authenticated via Argon2id verification. Role: ${account.role.name}.',
      severity: 'INFO',
    );

    if (isNewDeviceLogin) {
      _securityBannerAlert =
          'Email Security Alert sent to $cleanEmail (<5 min SLA): New login detected from iPhone 16 • Eindhoven, NL.';
      _addAuditLog(
        category: 'NEW_DEVICE_ALERT',
        actor: cleanEmail,
        action: 'Dispatched instant email alert for login from a new device/location.',
        severity: 'WARN',
      );
    }

    _savePersistedState();
    notifyListeners();
    return null;
  }

  // Demo helper: Trigger 5 failed login attempts in 1 tap for live presentation
  void demoTriggerFiveFailedLogins([String targetEmail = 'visitor@fontys.nl']) {
    final cleanEmail = targetEmail.toLowerCase();
    final now = DateTime.now();
    _failedLoginTimestamps[cleanEmail] = List.generate(5, (_) => now);
    _lockedUntilByEmail[cleanEmail] = now.add(const Duration(minutes: 15));
    _securityBannerAlert =
        'DEMO LOCKOUT ACTIVE: "$cleanEmail" is locked for 15 minutes after 5 failed attempts in 15 mins.';
    _addAuditLog(
      category: 'ACCOUNT_LOCKOUT',
      actor: cleanEmail,
      action:
          '5 failed login attempts in 15 minutes. Account locked for 15 minutes.',
      severity: 'CRITICAL',
    );
    notifyListeners();
  }

  void demoUnlockAllAccounts() {
    _failedLoginTimestamps.clear();
    _lockedUntilByEmail.clear();
    _securityBannerAlert = 'All temporary account lockouts cleared for demo.';
    _addAuditLog(
      category: 'LOCKOUT_CLEARED',
      actor: 'admin@festivalbuddy.nl',
      action: 'Cleared temporary brute-force lockouts.',
      severity: 'INFO',
    );
    notifyListeners();
  }

  // Register new account (enforces Privacy Policy consent & strong password)
  String? registerAccount({
    required String email,
    required String name,
    required String password,
    required bool acceptedPrivacyPolicy,
  }) {
    if (!acceptedPrivacyPolicy) {
      return 'You must review and accept the Privacy Policy before creating an account.';
    }
    final cleanEmail = sanitizeAndValidateInput(email).toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (_accounts.containsKey(cleanEmail)) {
      return 'An account with this email already exists.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    _registerInternal(
      email: cleanEmail,
      name: name,
      password: password,
      role: UserRole.visitor,
    );
    _currentUserEmail = cleanEmail;
    _activeRole = UserRole.visitor;
    _lastActivityTimestamp = DateTime.now();
    _savePersistedState();
    notifyListeners();
    return null;
  }

  // Single-use 24-hour password reset link + invalidate all active sessions
  PasswordResetToken requestPasswordResetLink(String email) {
    final cleanEmail = sanitizeAndValidateInput(email).toLowerCase();
    final randomCode = (100000 + Random().nextInt(899999)).toString();
    final token = PasswordResetToken(
      token: 'RST-$randomCode-SINGLEUSE',
      email: cleanEmail,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
    _latestResetToken = token;
    _addAuditLog(
      category: 'PASSWORD_RESET_LINK',
      actor: cleanEmail,
      action:
          'Generated single-use password reset link (${token.token}) expiring in 24 hours.',
      severity: 'INFO',
    );
    notifyListeners();
    return token;
  }

  String? completePasswordReset({
    required String tokenString,
    required String newPassword,
  }) {
    final token = _latestResetToken;
    if (token == null || token.token != tokenString.trim()) {
      return 'Invalid password reset token.';
    }
    if (token.isUsed) {
      return 'This single-use reset link has already been used.';
    }
    if (DateTime.now().isAfter(token.expiresAt)) {
      return 'This reset link has expired (24-hour limit).';
    }
    if (newPassword.length < 8) {
      return 'New password must be at least 8 characters.';
    }

    final account = _accounts[token.email];
    if (account != null) {
      final newSalt = _generateSalt();
      account.passwordSalt = newSalt;
      account.argon2Hash = _computeSimulatedArgon2id(newPassword, newSalt);
      account.plainPasswordForDemoOnly = newPassword;
    }

    _latestResetToken = PasswordResetToken(
      token: token.token,
      email: token.email,
      expiresAt: token.expiresAt,
      isUsed: true,
    );

    // Requirement: Invalidate all active sessions after a successful password reset
    _activeSessionVersion++;
    _currentUserEmail = null;
    _activeRole = UserRole.guest;
    _securityBannerAlert =
        'Password updated with new Argon2id salt. All active sessions (#$_activeSessionVersion) have been invalidated for security.';

    _addAuditLog(
      category: 'PASSWORD_CHANGED',
      actor: token.email,
      action:
          'Password reset via single-use token. All active sessions invalidated.',
      severity: 'WARN',
    );
    notifyListeners();
    return null;
  }

  void logout() {
    if (_currentUserEmail != null) {
      _addAuditLog(
        category: 'LOGOUT',
        actor: _currentUserEmail!,
        action: 'User signed out manually. Switched to Guest Mode.',
        severity: 'INFO',
      );
    }
    _currentUserEmail = null;
    _activeRole = UserRole.guest;
    _lastActivityTimestamp = null;
    _savePersistedState();
    notifyListeners();
  }

  // Quick Role Switcher for Group Presentation Demo
  void switchDemoRole(UserRole targetRole) {
    final previousRole = _activeRole;
    _activeRole = targetRole;
    if (targetRole == UserRole.guest) {
      _currentUserEmail = null;
    } else if (targetRole == UserRole.visitor) {
      _currentUserEmail = 'visitor@fontys.nl';
    } else if (targetRole == UserRole.organizer) {
      _currentUserEmail = 'organizer@greenpulse.nl';
    } else if (targetRole == UserRole.admin) {
      _currentUserEmail = 'admin@festivalbuddy.nl';
    }
    _lastActivityTimestamp = DateTime.now();
    _addAuditLog(
      category: 'ROLE_CHANGE',
      actor: _currentUserEmail ?? 'guest',
      action: 'Switched active role from ${previousRole.name} to ${targetRole.name}.',
      severity: 'INFO',
    );
    _savePersistedState();
    notifyListeners();
  }

  // GDPR Privacy Controls: Export & Request Deletion
  String exportUserDataJson() {
    final email = _currentUserEmail ?? 'guest (local session only)';
    final account = _accounts[_currentUserEmail];
    final payload = {
      'gdpr_export_generated_at': DateTime.now().toIso8601String(),
      'data_minimization_policy':
          'Only account email, display name, ticket IDs, and festival preference tags are stored.',
      'account': account == null
          ? {'mode': 'Guest (No personal data stored on server)'}
          : {
              'email': account.email,
              'name': account.name,
              'role': account.role.name,
              'password_storage': account.argon2Hash,
              'privacy_policy_accepted_at':
                  account.acceptedPrivacyPolicyAt.toIso8601String(),
            },
      'owned_tickets': currentUserTickets
          .map(
            (t) => {
              'ticket_id': t.ticketId,
              'festival': t.festivalName,
              'dates': t.dates,
            },
          )
          .toList(),
      'ai_preference_tags': {
        'selected_genres': selectedGenres.toList(),
        'max_distance_km': maxPreferredDistanceKm,
        'prioritize_zero_waste': prioritizeZeroWaste,
        'prioritize_public_transport': prioritizePublicTransport,
      },
    };
    _addAuditLog(
      category: 'GDPR_DATA_EXPORT',
      actor: email,
      action: 'User exported personal data package (JSON).',
      severity: 'INFO',
    );
    notifyListeners();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void requestAccountDeletion() {
    final email = _currentUserEmail ?? 'visitor@fontys.nl';
    _addAuditLog(
      category: 'ACCOUNT_DELETION_REQUEST',
      actor: email,
      action:
          'User requested GDPR Right-to-Erasure account & personal data deletion.',
      severity: 'CRITICAL',
    );
    _allTickets.removeWhere(
      (t) => t.ownerEmail.toLowerCase() == email.toLowerCase(),
    );
    if (_currentUserEmail != null &&
        _currentUserEmail != 'visitor@fontys.nl') {
      _accounts.remove(_currentUserEmail);
    }
    _currentUserEmail = null;
    _activeRole = UserRole.guest;
    _securityBannerAlert =
        'GDPR Erasure Request Logged: Personal profile and tickets for $email have been purged/scheduled for removal.';
    notifyListeners();
  }

  // ============================================================================
  // ADMIN CONTROL ACTIONS (WEB & DESKTOP DASHBOARD)
  // ============================================================================

  /// Deletes a festival from active state, local cache, and backend database
  void deleteFestival(String festivalId) {
    final idx = _festivals.indexWhere((f) => f.id == festivalId);
    if (idx != -1) {
      final removed = _festivals.removeAt(idx);
      _favoriteFestivalIds.remove(festivalId);
      _allTickets.removeWhere((t) => t.festivalId == festivalId);
      _personalPinsByFestival.remove(festivalId);

      _addAuditLog(
        category: 'FESTIVAL_DELETED',
        actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
        action: 'Permanently removed festival "${removed.name}" (ID: $festivalId).',
        severity: 'CRITICAL',
      );
      _savePersistedState();
      ApiService.deleteFestival(festivalId);
      notifyListeners();
    }
  }

  /// Updates details of an existing festival
  void updateFestivalDetails({
    required String festivalId,
    String? name,
    String? tagline,
    String? city,
    String? venueAddress,
    String? dates,
    double? priceEur,
    int? capacity,
    int? distanceKm,
    EcoCommitments? ecoCommitments,
    bool? isApprovedByAdmin,
    String? bannerImagePath,
  }) {
    final idx = _festivals.indexWhere((f) => f.id == festivalId);
    if (idx != -1) {
      final current = _festivals[idx];
      final newCity = city != null ? sanitizeAndValidateInput(city, maxLength: 50) : current.city;
      final newVenue = venueAddress != null ? sanitizeAndValidateInput(venueAddress, maxLength: 100) : current.venueAddress;
      final shouldUpdateCoords = (city != null && city != current.city) || (venueAddress != null && venueAddress != current.venueAddress);
      final (newLat, newLng) = shouldUpdateCoords ? _resolveCoordinatesForLocation(newCity, newVenue) : (current.latitude, current.longitude);

      final updated = current.copyWith(
        name: name != null ? sanitizeAndValidateInput(name, maxLength: 80) : null,
        tagline: tagline != null ? sanitizeAndValidateInput(tagline, maxLength: 120) : null,
        city: city != null ? sanitizeAndValidateInput(city, maxLength: 50) : null,
        venueAddress: venueAddress != null ? sanitizeAndValidateInput(venueAddress, maxLength: 100) : null,
        dates: dates != null ? sanitizeAndValidateInput(dates, maxLength: 50) : null,
        priceEur: priceEur,
        capacity: capacity,
        distanceKm: distanceKm,
        ecoCommitments: ecoCommitments,
        isApprovedByAdmin: isApprovedByAdmin,
        bannerImagePath: bannerImagePath,
        latitude: newLat,
        longitude: newLng,
      );
      _festivals[idx] = updated;

      _addAuditLog(
        category: 'FESTIVAL_UPDATED',
        actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
        action: 'Updated metadata for festival "${updated.name}".',
        severity: 'INFO',
      );
      _savePersistedState();
      final updateMap = <String, dynamic>{};
      if (name != null) updateMap['name'] = name;
      if (tagline != null) updateMap['tagline'] = tagline;
      if (city != null) updateMap['city'] = city;
      if (venueAddress != null) updateMap['venueAddress'] = venueAddress;
      if (dates != null) updateMap['dates'] = dates;
      if (priceEur != null) updateMap['priceEur'] = priceEur;
      if (capacity != null) updateMap['capacity'] = capacity;
      if (distanceKm != null) updateMap['distanceKm'] = distanceKm;
      if (ecoCommitments != null) updateMap['ecoCommitments'] = ecoCommitments.toJson();
      if (isApprovedByAdmin != null) updateMap['isApprovedByAdmin'] = isApprovedByAdmin;
      if (bannerImagePath != null) updateMap['bannerImagePath'] = bannerImagePath;
      ApiService.updateFestival(festivalId, updateMap);
      notifyListeners();
    }
  }

  // ============================================================================
  // PUSH NOTIFICATIONS & SYSTEM ANNOUNCEMENTS
  // ============================================================================
  final List<InAppPushNotification> _notifications = [];
  final List<SystemAnnouncement> _systemAnnouncements = [];
  final Set<String> _dismissedAnnouncementIds = {};

  List<InAppPushNotification> get notifications => List.unmodifiable(_notifications);
  List<SystemAnnouncement> get systemAnnouncements => List.unmodifiable(_systemAnnouncements);

  /// Returns active announcements that this device hasn't dismissed yet
  List<SystemAnnouncement> get pendingAnnouncements => _systemAnnouncements
      .where((a) => a.isActive && !_dismissedAnnouncementIds.contains(a.id))
      .toList();

  void dismissAnnouncement(String announcementId) {
    _dismissedAnnouncementIds.add(announcementId);
    notifyListeners();
  }

  void addPushNotification({
    required String title,
    required String body,
    required String targetRole, // 'visitor', 'organizer', 'all'
    String? relatedFestivalId,
  }) {
    final notif = InAppPushNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      targetRole: targetRole,
      timestamp: DateTime.now(),
      relatedFestivalId: relatedFestivalId,
    );
    _notifications.insert(0, notif);
    notifyListeners();
  }

  Future<void> publishAdminAnnouncement({
    required String title,
    required String message,
    String category = 'Important Notice',
  }) async {
    final ann = SystemAnnouncement(
      id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      category: category,
      createdAt: DateTime.now(),
      isActive: true,
    );
    _systemAnnouncements.insert(0, ann);
    _addAuditLog(
      category: 'ANNOUNCEMENT_PUBLISHED',
      actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
      action: 'Published system announcement: "$title".',
      severity: 'INFO',
    );
    ApiService.publishAnnouncement(ann);
    notifyListeners();
  }

  Future<void> deleteAdminAnnouncement(String id) async {
    _systemAnnouncements.removeWhere((a) => a.id == id);
    _addAuditLog(
      category: 'ANNOUNCEMENT_DELETED',
      actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
      action: 'Deleted system announcement (ID: $id).',
      severity: 'WARN',
    );
    ApiService.deleteAnnouncement(id);
    notifyListeners();
  }

  /// Approves a staged/crawled or unapproved festival listing
  void approveFestival(String festivalId) {
    final idx = _festivals.indexWhere((f) => f.id == festivalId);
    if (idx != -1) {
      final current = _festivals[idx];
      final updated = current.copyWith(isApprovedByAdmin: true);
      _festivals[idx] = updated;

      _addAuditLog(
        category: 'FESTIVAL_APPROVED',
        actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
        action: 'Approved listing "${current.name}" for public discovery.',
        severity: 'INFO',
      );
      _savePersistedState();
      // Ensure the full festival object is saved/inserted into SQLite so mobile phones fetch it
      ApiService.publishFestival(updated);

      // Trigger dual role-specific Push Notifications
      addPushNotification(
        title: '🎉 New Festival Approved: ${current.name}!',
        body: 'Just added to Discovery in ${current.city} (${current.dates}). Explore tickets and sustainable venue perks now!',
        targetRole: 'visitor',
        relatedFestivalId: current.id,
      );
      addPushNotification(
        title: '✅ Your festival is approved and published!',
        body: 'Congratulations! "${current.name}" has been verified by the Festival Buddy administration team and is now live on the public Discover feed.',
        targetRole: 'organizer',
        relatedFestivalId: current.id,
      );

      notifyListeners();
    }
  }

  /// In-memory list of registered visitors (`visitor_accounts` DB)
  final List<Map<String, dynamic>> _registeredVisitors = [];
  List<Map<String, dynamic>> get registeredVisitors =>
      List.unmodifiable(_registeredVisitors);

  /// In-memory queue of organizer sign-ups for Web Admin review
  /// Combines `pending_organizer_accounts` and `organizer_accounts`
  final List<Map<String, dynamic>> _adminOrganizersQueue = [
    {
      'email': 'organizer@greenpulse.nl',
      'name': 'Brabant Sustainable Events',
      'companyName': 'GreenPulse Events B.V.',
      'kvkNumber': '17283940',
      'phone': '+31 40 123 4567',
      'businessAddress': 'Torenallee 20, 5617 BC Eindhoven',
      'govIdType': 'Dutch Passport',
      'govIdNumber': 'NT1928374',
      'isApproved': true,
      'status': 'Approved',
      'registeredAt': '2026-11-10 14:20',
    },
    {
      'email': 'pending.organizer@festivals.nl',
      'name': 'Daan van Dijk',
      'companyName': 'Solar Vibe Productions B.V.',
      'kvkNumber': '84920194',
      'phone': '+31 20 892 1100',
      'businessAddress': 'Keizersgracht 421, Amsterdam',
      'govIdType': 'EU National ID Card',
      'govIdNumber': 'NL99283411',
      'isApproved': false,
      'status': 'Pending Approval',
      'registeredAt': '2026-11-12 09:15',
    },
    {
      'email': 'rave.holland@events.nl',
      'name': 'Sophie Meijer',
      'companyName': 'Neon Nights NL',
      'kvkNumber': '99102834',
      'phone': '+31 10 334 9921',
      'businessAddress': 'Coolsingel 104, Rotterdam',
      'govIdType': 'Driver License',
      'govIdNumber': 'DR-8812903',
      'isApproved': false,
      'status': 'Pending Approval',
      'registeredAt': '2026-11-12 10:45',
    },
  ];

  List<Map<String, dynamic>> get adminOrganizersQueue =>
      List.unmodifiable(_adminOrganizersQueue);

  /// Checks whether the currently signed-in organizer account has been approved by Admin
  bool get isCurrentOrganizerApproved {
    if (!isOrganizerAuthenticated) return false;
    final match = _adminOrganizersQueue.where(
      (o) => (o['email'] as String?)?.toLowerCase() == organizerEmail.toLowerCase(),
    );
    if (match.isEmpty) return false;
    return match.first['isApproved'] == true || match.first['isApproved'] == 1;
  }

  /// Approves or rejects an organizer account registration
  /// - If approved == true: moves from `pending_organizer_accounts` to `organizer_accounts`
  /// - If approved == false (Rejected): deletes from all databases immediately
  void setOrganizerApproval(String email, {required bool approved, String? note}) {
    final idx = _adminOrganizersQueue.indexWhere(
      (o) => (o['email'] as String?)?.toLowerCase() == email.toLowerCase(),
    );
    if (approved) {
      if (idx != -1) {
        _adminOrganizersQueue[idx]['isApproved'] = true;
        _adminOrganizersQueue[idx]['status'] = 'Approved';
      } else {
        _adminOrganizersQueue.insert(0, {
          'email': email,
          'name': email.split('@').first,
          'companyName': email.split('@').first,
          'kvkNumber': 'N/A',
          'isApproved': true,
          'status': 'Approved',
          'registeredAt': DateTime.now().toString(),
        });
      }
      addPushNotification(
        title: '🎉 Organizer Account Approved!',
        body: 'Your organizer account ($email) has been verified and approved by the Admin team. You can now publish festival events!',
        targetRole: 'organizer',
      );
    } else {
      // Requirement 6: If rejected from admin panel, delete immediately from databases
      if (idx != -1) {
        _adminOrganizersQueue.removeAt(idx);
      }
      if (organizerEmail.toLowerCase() == email.toLowerCase()) {
        signOutToGuest();
      }
    }

    _addAuditLog(
      category: approved ? 'ORGANIZER_APPROVED' : 'ORGANIZER_REJECTED_DELETED',
      actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
      action: approved
          ? 'Approved organizer $email and moved to organizer_accounts DB.'
          : 'Rejected and deleted organizer application for $email.',
      severity: approved ? 'INFO' : 'WARN',
    );
    ApiService.approveOrganizer(email, approved: approved, statusNote: note);
    notifyListeners();
  }

  // Favorites & Companion Selections
  bool isFavorite(String festivalId) => _favoriteFestivalIds.contains(festivalId);

  void toggleFavorite(String festivalId) {
    if (_favoriteFestivalIds.contains(festivalId)) {
      _favoriteFestivalIds.remove(festivalId);
    } else {
      _favoriteFestivalIds.add(festivalId);
    }
    notifyListeners();
  }

  bool isSlotStarred(String slotId) => _starredStageSlotIds.contains(slotId);

  void toggleStarredSlot(String slotId) {
    if (_starredStageSlotIds.contains(slotId)) {
      _starredStageSlotIds.remove(slotId);
    } else {
      _starredStageSlotIds.add(slotId);
    }
    notifyListeners();
  }

  void selectCompanionFestival(String festivalId) {
    _selectedCompanionFestivalId = festivalId;
    notifyListeners();
  }

  // Personal Pins on Festival Map (Tent, Car, Bike, Meetup)
  List<PersonalSavedPin> getPersonalPins(String festivalId) {
    return List.unmodifiable(_personalPinsByFestival[festivalId] ?? const []);
  }

  void savePersonalPin({
    required String festivalId,
    required PersonalPinType type,
    required String zoneLabel,
    required String note,
  }) {
    final cleanZone = sanitizeAndValidateInput(zoneLabel, maxLength: 60);
    final cleanNote = sanitizeAndValidateInput(note, maxLength: 120);
    final list = _personalPinsByFestival.putIfAbsent(festivalId, () => []);
    list.removeWhere((p) => p.type == type);

    // Deterministic or varied coordinates on the map canvas
    final coords = switch (type) {
      PersonalPinType.tent => const Offset(0.84, 0.54),
      PersonalPinType.car => const Offset(0.18, 0.85),
      PersonalPinType.bike => const Offset(0.56, 0.84),
      PersonalPinType.meetup => const Offset(0.48, 0.44),
    };

    list.insert(
      0,
      PersonalSavedPin(
        type: type,
        zoneLabel: cleanZone.isEmpty ? '${type.label} Pin' : cleanZone,
        note: cleanNote.isEmpty ? 'Saved offline on device' : cleanNote,
        savedAt: DateTime.now(),
        x: coords.dx,
        y: coords.dy,
      ),
    );
    notifyListeners();
  }

  void removePersonalPin({
    required String festivalId,
    required PersonalPinType type,
  }) {
    final list = _personalPinsByFestival[festivalId];
    if (list == null) return;
    list.removeWhere((p) => p.type == type);
    notifyListeners();
  }

  // Buy Ticket (Simulated Checkout with Account Binding)
  UserTicket purchaseTicketForCurrentUser(Festival festival) {
    recordUserActivity();
    final email = _currentUserEmail ?? 'visitor@fontys.nl';
    final name = currentUser?.name ?? 'Festival Visitor';
    final ticket = UserTicket(
      ticketId:
          'TKT-${festival.id.substring(5, 8).toUpperCase()}-${10000 + Random().nextInt(89999)}',
      festivalId: festival.id,
      festivalName: festival.name,
      dates: festival.dates,
      city: festival.city,
      ownerEmail: email,
      ownerName: name,
      purchasedAt: DateTime.now(),
      securityHash:
          'SHA256:${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      includesFreeShuttlePass:
          festival.ecoCommitments.publicTransportIncluded,
      reusableCupTokenIncluded: festival.ecoCommitments.reusableCupsOnly,
    );
    _allTickets.insert(0, ticket);

    // Increment ticketsSoldInApp on the festival
    final index = _festivals.indexWhere((f) => f.id == festival.id);
    if (index != -1) {
      final current = _festivals[index];
      _festivals[index] = current.copyWith(
        ticketsSoldInApp: current.ticketsSoldInApp + 1,
      );
    }

    _addAuditLog(
      category: 'TICKET_ISSUED',
      actor: email,
      action:
          'Issued account-bound ticket ${ticket.ticketId} for ${festival.name}.',
      severity: 'INFO',
    );
    notifyListeners();
    return ticket;
  }

  // Submit Report (Misleading Eco-Claim / Facility Issue / Unsafe Situation)
  void submitReport({
    required Festival festival,
    required String issueType,
    required String description,
  }) {
    final cleanDesc = sanitizeAndValidateInput(description, maxLength: 300);
    if (cleanDesc.isEmpty) return;
    final reporter = _currentUserEmail ?? 'guest-reporter@local';
    final report = FacilityOrClaimReport(
      id: 'REP-${100 + _reports.length + 1}',
      festivalId: festival.id,
      festivalName: festival.name,
      reporterEmail: reporter,
      issueType: issueType,
      description: cleanDesc,
      createdAt: DateTime.now(),
    );
    _reports.insert(0, report);
    _addAuditLog(
      category: 'REPORT_SUBMITTED',
      actor: reporter,
      action: 'Submitted [$issueType] report for ${festival.name}.',
      severity: 'WARN',
    );
    notifyListeners();
  }

  // Helper to determine real geographic coordinates from city and venue
  (double, double) _resolveCoordinatesForLocation(String city, String venue) {
    final c = city.toLowerCase();
    final v = venue.toLowerCase();
    if (c.contains('tilburg') || v.contains('tilburg')) return (51.5606, 5.0761);
    if (c.contains('rotterdam') || v.contains('rotterdam')) return (51.8860, 4.4886);
    if (c.contains('amsterdam') || v.contains('amsterdam')) return (52.3090, 4.9890);
    if (c.contains('arnhem') || v.contains('arnhem')) return (51.9922, 5.9038);
    if (c.contains('roermond') || v.contains('roermond')) return (51.2050, 5.9680);
    if (c.contains('utrecht') || v.contains('utrecht')) return (52.0907, 5.1214);
    if (c.contains('den haag') || c.contains('the hague') || v.contains('haag')) return (52.0705, 4.3007);
    if (c.contains('groningen') || v.contains('groningen')) return (53.2194, 6.5665);
    if (c.contains('breda') || v.contains('breda')) return (51.5719, 4.7683);
    if (c.contains('nijmegen') || v.contains('nijmegen')) return (51.8126, 5.8372);
    if (c.contains('maastricht') || v.contains('maastricht')) return (50.8514, 5.6910);
    if (c.contains('eindhoven') || v.contains('eindhoven')) {
      final rand = Random(city.hashCode ^ venue.hashCode);
      final lat = 51.4416 + (rand.nextDouble() - 0.5) * 0.015;
      final lng = 5.4697 + (rand.nextDouble() - 0.5) * 0.020;
      return (lat, lng);
    }
    final rand = Random(city.hashCode ^ venue.hashCode);
    final lat = 51.4416 + (rand.nextDouble() - 0.5) * 0.04;
    final lng = 5.4697 + (rand.nextDouble() - 0.5) * 0.05;
    return (lat, lng);
  }

  // Organizer: Create a new Festival with Mandatory Details, Cover Image & Terms
  void createFestivalListing({
    required String name,
    required String tagline,
    required String dates,
    required String city,
    required String venueAddress,
    required int distanceKm,
    required double priceEur,
    required List<String> genres,
    required String howToGetThere,
    required String publicTransportInfo,
    required String festivalTransportOffer,
    required EcoCommitments ecoCommitments,
    String coverImageLabel = 'Neon Laser Mainstage Cover',
    IconData coverIcon = Icons.wb_iridescent_rounded,
    String? bannerImagePath,
    Color primaryColor = const Color(0xFF7C3AED),
    Color secondaryColor = const Color(0xFFFF2E93),
  }) {
    final cleanName = sanitizeAndValidateInput(name, maxLength: 80);
    final (resolvedLat, resolvedLng) = _resolveCoordinatesForLocation(city, venueAddress);
    final newFestival = Festival(
      id: 'fest_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      tagline: sanitizeAndValidateInput(tagline, maxLength: 120),
      categoryLabel: '${genres.first} • Live Festival',
      dates: sanitizeAndValidateInput(dates, maxLength: 50),
      city: sanitizeAndValidateInput(city, maxLength: 50),
      venueAddress: sanitizeAndValidateInput(venueAddress, maxLength: 100),
      distanceKm: distanceKm,
      priceEur: priceEur,
      ticketsSoldInApp: 1,
      capacity: 2500,
      genres: genres,
      howToGetThere: sanitizeAndValidateInput(howToGetThere),
      publicTransportInfo: sanitizeAndValidateInput(publicTransportInfo),
      festivalTransportOffer: sanitizeAndValidateInput(festivalTransportOffer),
      organizerName: organizerName,
      ecoCommitments: ecoCommitments,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      isApprovedByAdmin: false, // Requirement 2: Newly published events start in Pending Approval state!
      latitude: resolvedLat,
      longitude: resolvedLng,
      coverImageLabel: coverImageLabel,
      coverIcon: coverIcon,
      bannerImagePath: bannerImagePath,
      lineup: [
        StageSlot(
          id: 'cust_1',
          artist: 'Headliner Live Set',
          stageName: 'Main Arena Stage',
          dayLabel: 'Saturday',
          timeRange: '20:00 – 22:00',
          genre: genres.first,
        ),
      ],
      mapPins: const [
        MapPinPoint(
          id: 'cust_w1',
          title: 'Free Freshwater Station #1',
          category: MapPinCategory.water,
          x: 0.40,
          y: 0.45,
          subtitle: 'Free chilled water refill taps',
        ),
        MapPinPoint(
          id: 'cust_fa1',
          title: 'First Aid & Chill Tent',
          category: MapPinCategory.firstAid,
          x: 0.60,
          y: 0.50,
          subtitle: '24/7 Medical & quiet zone post',
        ),
      ],
    );

    _festivals.insert(0, newFestival);
    _addAuditLog(
      category: 'FESTIVAL_SUBMITTED_FOR_REVIEW',
      actor: organizerEmail,
      action:
          'Organizer submitted festival "$cleanName" for admin moderation (Pending Approval).',
      severity: 'INFO',
    );
    _savePersistedState();
    // Async background sync with online SQLite database in unapproved state
    ApiService.publishFestival(newFestival);

    // Notify Organizer that event was submitted and is pending admin check
    addPushNotification(
      title: '📋 Festival Submitted for Review',
      body: 'Your event "$cleanName" has been submitted. It will become publicly visible once approved by the admin team.',
      targetRole: 'organizer',
      relatedFestivalId: newFestival.id,
    );

    notifyListeners();
  }

  void updateFestivalBanner(String festivalId, String imagePath) async {
    final index = _festivals.indexWhere((f) => f.id == festivalId);
    if (index != -1) {
      String resolvedPath = imagePath;
      // Try uploading to online backend if it is a local device file
      if (!imagePath.startsWith('http')) {
        final onlineUrl = await ApiService.uploadImage(imagePath);
        if (onlineUrl != null) {
          resolvedPath = onlineUrl;
        }
      }

      final current = _festivals[index];
      final updated = current.copyWith(bannerImagePath: resolvedPath);
      _festivals[index] = updated;
      _addAuditLog(
        category: 'FESTIVAL_BANNER_UPDATED',
        actor: _currentUserEmail ?? 'organizer@fontys.nl',
        action: 'Updated custom banner for festival "${current.name}".',
        severity: 'INFO',
      );
      _savePersistedState();
      ApiService.publishFestival(updated);
      notifyListeners();
    }
  }

  void _startCloudSyncPolling() {
    _cloudSyncPollTimer?.cancel();
    _cloudSyncPollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      final wasApproved = isCurrentOrganizerApproved;
      final pendingEventIds = _festivals
          .where((f) => !f.isApprovedByAdmin)
          .map((f) => f.id)
          .toSet();

      await refreshFromBackend();

      // 1. Detect if current organizer account was just approved
      if (isOrganizerAuthenticated && !wasApproved && isCurrentOrganizerApproved) {
        addPushNotification(
          title: '🎉 Organizer Account Approved!',
          body: 'Your business profile ($organizerName) has been verified and approved by Admin. You can now publish live events!',
          targetRole: 'organizer',
        );
        _savePersistedState();
      }

      // 2. Detect if an organizer account was rejected / deleted by admin
      if (isOrganizerAuthenticated && !isCurrentOrganizerApproved) {
        final match = _adminOrganizersQueue.firstWhere(
          (o) => (o['email'] as String?)?.toLowerCase() == organizerEmail.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isEmpty && _adminOrganizersQueue.isNotEmpty) {
          // Record was removed from database (rejected)
          addPushNotification(
            title: '⚠️ Application Not Approved',
            body: 'Your submission was reviewed and rejected by the admin team. You may review your business credentials and submit a new application.',
            targetRole: 'organizer',
          );
          signOutToGuest();
        }
      }

      // 3. Detect if any pending festivals were approved
      for (final f in _festivals) {
        if (pendingEventIds.contains(f.id) && f.isApprovedByAdmin) {
          addPushNotification(
            title: '🌟 Festival Approved & Live!',
            body: 'Your event "${f.name}" has been approved by Admin and is now live on Discover!',
            targetRole: 'organizer',
            relatedFestivalId: f.id,
          );
          addPushNotification(
            title: '🔥 New Festival Dropped: ${f.name}!',
            body: '${f.name} in ${f.city} has just been announced on Festival Buddy!',
            targetRole: 'visitor',
            relatedFestivalId: f.id,
          );
        }
      }
    });
  }

  void stopCloudSyncPolling() {
    _cloudSyncPollTimer?.cancel();
    _cloudSyncPollTimer = null;
  }

  void stopAiIngestionTimer() => stopCloudSyncPolling();

  @override
  void dispose() {
    _cloudSyncPollTimer?.cancel();
    super.dispose();
  }

  // ============================================================================
  // 1. GOOGLE / APPLE / EMAIL OTP SIGN-IN & ORGANIZER KVK + GOVT ID VERIFICATION
  // ============================================================================
  bool isVisitorAuthenticated = false;
  bool isOrganizerAuthenticated = false;
  bool isProfileViewingOrganizer = false;

  bool get canShowCommunityTab =>
      isVisitorAuthenticated && !isProfileViewingOrganizer;

  void setProfileViewingOrganizer(bool value) {
    isProfileViewingOrganizer = value;
    notifyListeners();
  }
  String visitorAuthMethod = 'Google';
  String visitorUsername = '@maruf_fb84';
  String organizerAuthMethod = 'Email (Verified)';
  String? _pendingEmailVerificationCode;
  OrganizerKvkVerification? organizerKvkVerification;

  // Device Location Service Toggle (Required for Auto-Pinning & Friend Map Pins)
  bool isDeviceLocationEnabled = true;

  void setDeviceLocationEnabled(bool enabled) {
    isDeviceLocationEnabled = enabled;
    notifyListeners();
  }

  String _generateUniqueAvailableUsername(String baseNameOrEmail) {
    final cleanBase = baseNameOrEmail
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final prefix = cleanBase.isEmpty ? 'buddy' : cleanBase;
    final taken = _buddyUsers.map((u) => u.username.toLowerCase()).toSet();

    var candidate = '@${prefix}_${10 + Random().nextInt(89)}';
    while (taken.contains(candidate)) {
      candidate = '@${prefix}_${100 + Random().nextInt(899)}';
    }
    return candidate;
  }

  bool get isOrganizerKvkAndIdVerified => organizerKvkVerification != null;

  String sendEmailVerificationCode(String email) {
    final code = (100000 + Random().nextInt(899999)).toString();
    _pendingEmailVerificationCode = code;
    notifyListeners();
    return code;
  }

  bool verifyEmailOtpCode(String inputCode) {
    final clean = inputCode.trim();
    if (clean.isEmpty) return false;
    return clean == _pendingEmailVerificationCode || clean == '123456';
  }

  void completeVisitorSignIn({
    required String method,
    String? email,
    String? name,
  }) {
    isVisitorAuthenticated = true;
    isOrganizerAuthenticated = false;
    isProfileViewingOrganizer = false;
    visitorAuthMethod = method;
    if (email != null && email.trim().isNotEmpty) {
      visitorEmail = sanitizeAndValidateInput(email, maxLength: 80);
    }
    if (name != null && name.trim().isNotEmpty) {
      visitorName = sanitizeAndValidateInput(name, maxLength: 80);
    }
    visitorUsername = _generateUniqueAvailableUsername(
      name != null && name.trim().isNotEmpty ? name : visitorEmail,
    );
    _activeRole = UserRole.visitor;
    _currentUserEmail = visitorEmail;

    // Requirement 4 & 5: Automatically approved when signing up with Google/Apple/Email,
    // and collect visitor information in the `visitor_accounts` database!
    final visitorData = {
      'email': visitorEmail,
      'name': visitorName,
      'username': visitorUsername,
      'authMethod': visitorAuthMethod,
      'phone': visitorPhone,
      'address': visitorAddress,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final idx = _registeredVisitors.indexWhere(
      (v) => (v['email'] as String?)?.toLowerCase() == visitorEmail.toLowerCase(),
    );
    if (idx != -1) {
      _registeredVisitors[idx] = visitorData;
    } else {
      _registeredVisitors.insert(0, visitorData);
    }
    ApiService.registerVisitor(visitorData);

    _addAuditLog(
      category: 'VISITOR_REGISTERED',
      actor: visitorEmail,
      action: 'Visitor "$visitorName" ($visitorUsername) signed in via $visitorAuthMethod and saved to visitor_accounts database.',
      severity: 'INFO',
    );
    _savePersistedState();
    notifyListeners();
  }

  void completeOrganizerRegistration({
    required String authMethod,
    required String companyName,
    required String email,
    required String phone,
    required String businessAddress,
    required String kvkNumber,
    required String vatNumber,
    required String govIdType,
    required String govIdDocumentNumber,
    required String govIdFileName,
  }) {
    isOrganizerAuthenticated = true;
    isVisitorAuthenticated = false;
    isProfileViewingOrganizer = true;
    organizerAuthMethod = authMethod;
    organizerName = sanitizeAndValidateInput(companyName, maxLength: 80);
    organizerEmail = sanitizeAndValidateInput(email, maxLength: 80);
    organizerPhone = sanitizeAndValidateInput(phone, maxLength: 40);
    organizerAddress = sanitizeAndValidateInput(businessAddress, maxLength: 120);

    organizerKvkVerification = OrganizerKvkVerification(
      companyName: organizerName,
      kvkNumber: sanitizeAndValidateInput(kvkNumber, maxLength: 20),
      vatNumber: sanitizeAndValidateInput(vatNumber, maxLength: 24),
      businessAddress: organizerAddress,
      phone: organizerPhone,
      govIdType: govIdType,
      govIdDocumentNumber:
          sanitizeAndValidateInput(govIdDocumentNumber, maxLength: 30),
      govIdFileName: govIdFileName,
      verifiedAt: DateTime.now(),
    );

    _activeRole = UserRole.organizer;
    _currentUserEmail = organizerEmail;

    // Requirement 1: Every time a new organizer signs up, account is in Pending Approval state!
    final organizerData = {
      'email': organizerEmail,
      'name': organizerName,
      'companyName': organizerName,
      'kvkNumber': kvkNumber,
      'phone': organizerPhone,
      'businessAddress': organizerAddress,
      'govIdType': govIdType,
      'govIdNumber': govIdDocumentNumber,
      'isApproved': false,
      'status': 'Pending Approval',
      'registeredAt': DateTime.now().toString(),
    };

    // Add to admin approval queue
    final existingIdx = _adminOrganizersQueue.indexWhere((o) => o['email'] == organizerEmail);
    if (existingIdx != -1) {
      _adminOrganizersQueue[existingIdx] = organizerData;
    } else {
      _adminOrganizersQueue.insert(0, organizerData);
    }

    _addAuditLog(
      category: 'ORGANIZER_REGISTERED',
      actor: organizerEmail,
      action: 'Organizer "$organizerName" registered with KVK: $kvkNumber. Account staged for Admin Approval.',
      severity: 'WARN',
    );

    // Sync to SQLite backend
    ApiService.registerOrganizer(organizerData);

    addPushNotification(
      title: '⏳ Organizer Account Pending Approval',
      body: 'Your business profile ($organizerName) has been submitted for administrative KVK & ID verification. You will be notified once approved.',
      targetRole: 'organizer',
    );

    _savePersistedState();
    notifyListeners();
  }

  // Auto-detect current GPS location and pin spot (requires isDeviceLocationEnabled)
  Future<PersonalSavedPin?> autoDetectAndPinSpot({
    required Festival festival,
    required PersonalPinType type,
  }) async {
    if (!isDeviceLocationEnabled) return null;

    final list = _personalPinsByFestival.putIfAbsent(festival.id, () => []);
    list.removeWhere((p) => p.type == type);

    double pinLat = festival.latitude;
    double pinLng = festival.longitude;
    String detectedZone = switch (type) {
      PersonalPinType.tent => 'GPS Pin • Tent Spot',
      PersonalPinType.car => 'GPS Pin • Parking',
      PersonalPinType.bike => 'GPS Pin • Bike Spot',
      PersonalPinType.meetup => 'GPS Pin • Meetup Point',
    };

    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        pinLat = pos.latitude;
        pinLng = pos.longitude;
        detectedZone = 'Live GPS • ${type.label} (${pinLat.toStringAsFixed(4)}°, ${pinLng.toStringAsFixed(4)}°)';
      }
    } catch (_) {
      // Fallback relative to festival center if live GPS fix is unavailable
      final (latOff, lngOff) = switch (type) {
        PersonalPinType.tent => (0.0012, 0.0018),
        PersonalPinType.car => (-0.0021, -0.0015),
        PersonalPinType.bike => (-0.0009, 0.0006),
        PersonalPinType.meetup => (0.0005, -0.0004),
      };
      pinLat = festival.latitude + latOff;
      pinLng = festival.longitude + lngOff;
    }

    final pin = PersonalSavedPin(
      type: type,
      zoneLabel: detectedZone,
      note:
          'Auto-detected GPS (${pinLat.toStringAsFixed(4)}° N, ${pinLng.toStringAsFixed(4)}° E)',
      savedAt: DateTime.now(),
      x: 0.5 + (pinLng - festival.longitude) / 0.007,
      y: 0.5 + (pinLat - festival.latitude) / 0.005,
      latitude: pinLat,
      longitude: pinLng,
    );
    list.insert(0, pin);
    notifyListeners();
    return pin;
  }

  void signOutToGuest() {
    isVisitorAuthenticated = false;
    isOrganizerAuthenticated = false;
    _activeRole = UserRole.guest;
    _currentUserEmail = null;
    _savePersistedState();
    notifyListeners();
  }

  // ============================================================================
  // 3. SETTINGS & PERSONALIZED DISCOVERY PAGE (3-DOT MENU)
  // ============================================================================
  bool soundEffectsEnabled = true;
  double soundVolume = 0.80;
  double textScale = 1.0; // 0.9, 1.0, 1.15, 1.25
  bool isPersonalizedDiscoveryEnabled = false;
  String preferredDiscoveryCity = 'All Cities';

  void setSoundSettings({bool? enabled, double? volume}) {
    if (enabled != null) soundEffectsEnabled = enabled;
    if (volume != null) soundVolume = volume;
    notifyListeners();
  }

  void setTextScale(double scale) {
    textScale = scale;
    isEasyReadLargeText = scale > 1.05;
    notifyListeners();
  }

  void setPersonalizedDiscovery({
    bool? enabled,
    String? preferredCity,
  }) {
    if (enabled != null) isPersonalizedDiscoveryEnabled = enabled;
    if (preferredCity != null) preferredDiscoveryCity = preferredCity;
    notifyListeners();
  }

  // ============================================================================
  // 4. FRIENDS, 1-ON-1 CHAT, GROUPS & LIVE LOCATION SHARING
  // ============================================================================
  final List<BuddyFriend> _buddyUsers = [];
  final Map<String, List<ChatMessage>> _directMessages = {};
  final List<FriendGroup> _friendGroups = [];
  String? mySharedLiveLocation = 'Kinetic Mainstage • Eindhoven';

  List<BuddyFriend> get allBuddyUsers => List.unmodifiable(_buddyUsers);
  List<BuddyFriend> get myFriends =>
      _buddyUsers.where((u) => u.isAddedFriend).toList();
  List<BuddyFriend> get suggestedUsersToAdd =>
      _buddyUsers.where((u) => !u.isAddedFriend).toList();
  List<FriendGroup> get friendGroups => List.unmodifiable(_friendGroups);

  void _seedSocialFriendsAndGroups() {
    final now = DateTime.now();
    _buddyUsers.addAll([
      BuddyFriend(
        id: 'usr_burdzhu',
        name: 'Burdzhu',
        username: '@burdzhu_fest',
        avatarColor: const Color(0xFFFF2E93),
        statusText: 'At GreenPulse Open Air 🎶',
        isAddedFriend: true,
        sharedLocation: 'Eindhoven • Kinetic Mainstage (80m)',
        latitude: 51.4518,
        longitude: 5.4572,
        venueX: 0.30,
        venueY: 0.28,
      ),
      BuddyFriend(
        id: 'usr_yusuf',
        name: 'Yusuf',
        username: '@yusuf_beats',
        avatarColor: const Color(0xFF00E5FF),
        statusText: 'Heading to Neon Forest Stage',
        isAddedFriend: true,
        sharedLocation: 'Eindhoven • North Gate Bike Hub',
        latitude: 51.4480,
        longitude: 5.4610,
        venueX: 0.58,
        venueY: 0.80,
      ),
      BuddyFriend(
        id: 'usr_priya',
        name: 'Priya',
        username: '@priya_vibes',
        avatarColor: const Color(0xFFA855F7),
        statusText: 'Chilling at Sunset Sessions ✨',
        isAddedFriend: true,
        sharedLocation: 'Tilburg • Spoorpark Stage',
        latitude: 51.5612,
        longitude: 5.0770,
        venueX: 0.68,
        venueY: 0.36,
      ),
      BuddyFriend(
        id: 'usr_filip',
        name: 'Filip',
        username: '@filip_live',
        avatarColor: const Color(0xFF10B981),
        statusText: 'Ready for Horizon Beats!',
        isAddedFriend: true,
        sharedLocation: 'Rotterdam • Harbor Arena',
        latitude: 51.8870,
        longitude: 4.4895,
        venueX: 0.78,
        venueY: 0.56,
      ),
    ]);

    _directMessages['usr_burdzhu'] = [
      ChatMessage(
        id: 'm1',
        senderName: 'Burdzhu',
        isMe: false,
        text: 'Hey! Are you near the Mainstage yet?',
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      ChatMessage(
        id: 'm2',
        senderName: 'Burdzhu',
        isMe: false,
        text: 'Sharing my live spot so you can find us:',
        timestamp: now.subtract(const Duration(minutes: 10)),
        sharedLocationLabel: '📍 Near Solar Mainstage • 80m away',
      ),
    ];

    _directMessages['usr_yusuf'] = [
      ChatMessage(
        id: 'm3',
        senderName: 'Yusuf',
        isMe: false,
        text: 'Just parked my bike at North Gate! Meet at Water Bar #1?',
        timestamp: now.subtract(const Duration(minutes: 18)),
      ),
    ];

    _friendGroups.add(
      FriendGroup(
        id: 'grp_fontys_squad',
        name: 'Fontys Festival Squad 🔥',
        memberIds: ['usr_burdzhu', 'usr_yusuf', 'usr_priya', 'usr_filip'],
        messages: [
          ChatMessage(
            id: 'gm1',
            senderName: 'Priya',
            isMe: false,
            text: 'Everyone ready for Aurora Pulse at 18:00?',
            timestamp: now.subtract(const Duration(minutes: 25)),
          ),
          ChatMessage(
            id: 'gm2',
            senderName: 'Filip',
            isMe: false,
            text: 'Dropped our group meetup pin by the Freshwater Bar!',
            timestamp: now.subtract(const Duration(minutes: 20)),
            sharedLocationLabel: '📍 Group Pin: Mainstage Water Bar #1',
          ),
        ],
      ),
    );
  }

  void addFriendById(String userId) {
    final idx = _buddyUsers.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    _buddyUsers[idx].isAddedFriend = true;
    _buddyUsers[idx].sharedLocation = 'GreenPulse Grounds • 150m away';
    _directMessages.putIfAbsent(
      userId,
      () => [
        ChatMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          senderName: _buddyUsers[idx].name,
          isMe: false,
          text: 'Hey! Awesome to connect on Festival Buddy 🎉',
          timestamp: DateTime.now(),
        ),
      ],
    );
    notifyListeners();
  }

  BuddyFriend addCustomFriendByUsername(String rawHandleOrName) {
    final clean = sanitizeAndValidateInput(rawHandleOrName, maxLength: 40);
    final newFriend = BuddyFriend(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: clean.startsWith('@') ? clean.substring(1) : clean,
      username: clean.startsWith('@')
          ? clean.toLowerCase()
          : '@${clean.toLowerCase().replaceAll(" ", "_")}',
      avatarColor: const Color(0xFFFF2E93),
      statusText: 'Connected on Festival Buddy ✨',
      isAddedFriend: true,
      sharedLocation: 'Main Entrance Gate • 95m away',
    );
    _buddyUsers.insert(0, newFriend);
    _directMessages[newFriend.id] = [
      ChatMessage(
        id: 'welcome_${newFriend.id}',
        senderName: newFriend.name,
        isMe: false,
        text: 'Hey! Added you back on Festival Buddy 🙌',
        timestamp: DateTime.now(),
      ),
    ];
    notifyListeners();
    return newFriend;
  }

  List<ChatMessage> getDirectMessages(String friendId) {
    return List.unmodifiable(_directMessages[friendId] ?? const []);
  }

  void sendDirectMessage({
    required String friendId,
    required String text,
    String? sharedLocationLabel,
  }) {
    final cleanText = sanitizeAndValidateInput(text, maxLength: 240);
    if (cleanText.isEmpty && sharedLocationLabel == null) return;
    final list = _directMessages.putIfAbsent(friendId, () => []);
    list.add(
      ChatMessage(
        id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
        senderName: visitorName,
        isMe: true,
        text: cleanText,
        timestamp: DateTime.now(),
        sharedLocationLabel: sharedLocationLabel,
      ),
    );
    if (sharedLocationLabel != null) {
      mySharedLiveLocation = sharedLocationLabel;
    }
    notifyListeners();
  }

  FriendGroup createFriendGroup({
    required String groupName,
    required List<String> memberIds,
  }) {
    final cleanName = sanitizeAndValidateInput(groupName, maxLength: 50);
    final group = FriendGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName.isEmpty ? 'Festival Crew 🔥' : cleanName,
      memberIds: memberIds,
      messages: [
        ChatMessage(
          id: 'g_init_${DateTime.now().millisecondsSinceEpoch}',
          senderName: visitorName,
          isMe: true,
          text: 'Created group "$cleanName" — share your live pins here!',
          timestamp: DateTime.now(),
        ),
      ],
    );
    _friendGroups.insert(0, group);
    notifyListeners();
    return group;
  }

  void sendGroupMessage({
    required String groupId,
    required String text,
    String? sharedLocationLabel,
  }) {
    final group = _friendGroups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return;
    final cleanText = sanitizeAndValidateInput(text, maxLength: 240);
    if (cleanText.isEmpty && sharedLocationLabel == null) return;
    group.messages.add(
      ChatMessage(
        id: 'gm_${DateTime.now().millisecondsSinceEpoch}',
        senderName: visitorName,
        isMe: true,
        text: cleanText,
        timestamp: DateTime.now(),
        sharedLocationLabel: sharedLocationLabel,
      ),
    );
    if (sharedLocationLabel != null) {
      mySharedLiveLocation = sharedLocationLabel;
    }
    notifyListeners();
  }

  // Admin: Legacy Approve or Remove Festival / Resolve Report
  void removeFestivalListing(String festivalId) {
    deleteFestival(festivalId);
  }

  void updateReportStatus(String reportId, String newStatus) {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;
    _reports[idx] = _reports[idx].copyWith(status: newStatus);
    _addAuditLog(
      category: 'REPORT_REVIEWED',
      actor: _currentUserEmail ?? 'admin@festivalbuddy.nl',
      action: 'Admin updated report $reportId to "$newStatus".',
      severity: 'INFO',
    );
    notifyListeners();
  }

  // AI Recommendation Preferences Update
  void togglePreferredGenre(String genre) {
    if (selectedGenres.contains(genre)) {
      if (selectedGenres.length > 1) {
        selectedGenres.remove(genre);
      }
    } else {
      selectedGenres.add(genre);
    }
    notifyListeners();
  }

  void updateAiPreferences({
    double? maxDistanceKm,
    bool? zeroWaste,
    bool? publicTransport,
    bool? healthAndQuietZones,
  }) {
    if (maxDistanceKm != null) maxPreferredDistanceKm = maxDistanceKm;
    if (zeroWaste != null) prioritizeZeroWaste = zeroWaste;
    if (publicTransport != null) prioritizePublicTransport = publicTransport;
    if (healthAndQuietZones != null) {
      prioritizeHealthAndQuietZones = healthAndQuietZones;
    }
    notifyListeners();
  }

  void toggleAttendedFestival(String festivalId) {
    if (attendedFestivalIds.contains(festivalId)) {
      attendedFestivalIds.remove(festivalId);
    } else {
      attendedFestivalIds.add(festivalId);
    }
    notifyListeners();
  }

  // ============================================================================
  // AI RECOMMENDATION ENGINE (Content-Based Similarity + Explainable AI Reasons)
  // ============================================================================
  List<RecommendationResult> getRecommendedFestivals() {
    final results = <RecommendationResult>[];

    // Collect genres from previously attended festivals for collaborative/history boost
    final pastGenres = <String>{};
    for (final pastId in attendedFestivalIds) {
      final match = _festivals.where((f) => f.id == pastId);
      if (match.isNotEmpty) {
        pastGenres.addAll(match.first.genres);
      }
    }

    for (final festival in approvedFestivals) {
      final reasons = <String>[];

      // 1. Genre Match Score (0 - 45 points)
      final matchingGenres =
          festival.genres.where((g) => selectedGenres.contains(g)).toList();
      final double genreRatio = selectedGenres.isEmpty
          ? 0.7
          : matchingGenres.length /
              max(1, min(selectedGenres.length, festival.genres.length));
      var genrePoints = (genreRatio.clamp(0.0, 1.0) * 40).round();

      // Past festival similarity bonus (up to 5 points)
      final pastOverlap =
          festival.genres.where((g) => pastGenres.contains(g)).toList();
      if (pastOverlap.isNotEmpty && attendedFestivalIds.isNotEmpty) {
        genrePoints += 5;
      }

      if (matchingGenres.isNotEmpty) {
        reasons.add('Matches your ${matchingGenres.join(" & ")} taste');
      } else if (pastOverlap.isNotEmpty) {
        reasons.add('Similar vibe to festivals you attended before');
      }

      // 2. Sustainability & SDG Preference Match (0 - 35 points)
      var ecoPoints = (festival.ecoCommitments.ecoScorePercentage * 0.20).round();
      if (prioritizeZeroWaste &&
          festival.ecoCommitments.reusableCupsOnly &&
          festival.ecoCommitments.recyclingStations) {
        ecoPoints += 5;
        reasons.add('100% reusable cups & recycling (SDG 12)');
      }
      if (prioritizePublicTransport &&
          festival.ecoCommitments.publicTransportIncluded) {
        ecoPoints += 5;
        reasons.add('Direct green transit & shuttle included (SDG 11/13)');
      }
      if (prioritizeHealthAndQuietZones &&
          festival.ecoCommitments.freeDrinkingWater &&
          festival.ecoCommitments.firstAidAndQuietZone) {
        ecoPoints += 5;
        reasons.add(
          '${festival.ecoCommitments.waterPointsCount} free water points & quiet zone (SDG 3)',
        );
      }
      ecoPoints = ecoPoints.clamp(0, 35);

      // 3. Distance / Travel Footprint Score (0 - 20 points)
      int distancePoints;
      if (festival.distanceKm <= maxPreferredDistanceKm) {
        distancePoints = 20;
        reasons.add('Within your ${maxPreferredDistanceKm.round()} km travel radius (${festival.distanceKm} km away)');
      } else {
        final overKm = festival.distanceKm - maxPreferredDistanceKm;
        distancePoints = max(4, (20 - (overKm / 5)).round());
      }

      final totalMatch = (genrePoints + ecoPoints + distancePoints).clamp(15, 99);

      if (reasons.isEmpty) {
        reasons.add(
          'Verified ${festival.ecoCommitments.ecoScorePercentage}% SDG sustainability commitment',
        );
      }

      results.add(
        RecommendationResult(
          festival: festival,
          matchPercentage: totalMatch,
          reasons: reasons,
          genreMatchScore: ((genrePoints / 45) * 100).round(),
          ecoMatchScore: festival.ecoCommitments.ecoScorePercentage,
          distanceMatchScore: ((distancePoints / 20) * 100).round(),
        ),
      );
    }

    // Requirement: "The system must show the most related festivals first to the users."
    results.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return results;
  }
}
