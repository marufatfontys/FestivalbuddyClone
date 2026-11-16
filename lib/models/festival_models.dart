import 'package:flutter/material.dart';

enum UserRole {
  guest,
  visitor,
  organizer,
  admin,
}

enum SdgGoal {
  sdg3(
    number: 3,
    title: 'Good Health & Well-Being',
    shortLabel: 'SDG 3: Health & Water',
    description:
        'Free drinking water points, first aid stations, healthy food options, and quiet rest areas.',
    color: Color(0xFF2E7D32),
    icon: Icons.water_drop_rounded,
  ),
  sdg11(
    number: 11,
    title: 'Sustainable Cities & Communities',
    shortLabel: 'SDG 11: Green Transit',
    description:
        'Public transport integration, shuttle buses, guarded bicycle parking, and low-noise zones.',
    color: Color(0xFFEF6C00),
    icon: Icons.directions_bus_filled_rounded,
  ),
  sdg12(
    number: 12,
    title: 'Responsible Consumption',
    shortLabel: 'SDG 12: Zero Waste',
    description:
        '100% hard reusable cup system, clearly marked recycling bins, and food-waste reduction.',
    color: Color(0xFFB7791F),
    icon: Icons.recycling_rounded,
  ),
  sdg13(
    number: 13,
    title: 'Climate Action',
    shortLabel: 'SDG 13: Climate Action',
    description:
        '100% renewable grid/solar power (no diesel generators) and low-carbon travel incentives.',
    color: Color(0xFF1B5E20),
    icon: Icons.bolt_rounded,
  ),
  sdg16(
    number: 16,
    title: 'Peace, Justice & Safe Spaces',
    shortLabel: 'SDG 16: Safe & Inclusive',
    description:
        'Trained safety stewards, anti-discrimination policy, clear safety rules, and fast incident reporting.',
    color: Color(0xFF1565C0),
    icon: Icons.shield_rounded,
  ),
  sdg17(
    number: 17,
    title: 'Partnerships for the Goals',
    shortLabel: 'SDG 17: Eco Partners',
    description:
        'Verified partnerships with local municipalities, NGOs, and regional sustainable suppliers.',
    color: Color(0xFF283593),
    icon: Icons.handshake_rounded,
  );

  const SdgGoal({
    required this.number,
    required this.title,
    required this.shortLabel,
    required this.description,
    required this.color,
    required this.icon,
  });

  final int number;
  final String title;
  final String shortLabel;
  final String description;
  final Color color;
  final IconData icon;
}

class EcoCommitments {
  const EcoCommitments({
    required this.freeDrinkingWater,
    required this.firstAidAndQuietZone,
    required this.publicTransportIncluded,
    required this.bicycleParking,
    required this.reusableCupsOnly,
    required this.recyclingStations,
    required this.renewableEnergy,
    required this.safeSpaceStewards,
    required this.localEcoPartners,
    this.waterPointsCount = 8,
    this.firstAidStationsCount = 3,
    this.recyclingPointsCount = 24,
  });

  final bool freeDrinkingWater;
  final bool firstAidAndQuietZone;
  final bool publicTransportIncluded;
  final bool bicycleParking;
  final bool reusableCupsOnly;
  final bool recyclingStations;
  final bool renewableEnergy;
  final bool safeSpaceStewards;
  final bool localEcoPartners;
  final int waterPointsCount;
  final int firstAidStationsCount;
  final int recyclingPointsCount;

  List<MapEntry<String, bool>> get checklistItems => [
        MapEntry(
          'Free freshwater refill points ($waterPointsCount stations)',
          freeDrinkingWater,
        ),
        MapEntry(
          'First Aid tents ($firstAidStationsCount) & Quiet Rest Zone',
          firstAidAndQuietZone,
        ),
        MapEntry(
          'Public transport / shuttle integration',
          publicTransportIncluded,
        ),
        MapEntry(
          'Guarded bicycle parking at entrance',
          bicycleParking,
        ),
        MapEntry(
          '100% Circular reusable cup deposit system',
          reusableCupsOnly,
        ),
        MapEntry(
          'Separated recycling bins ($recyclingPointsCount points)',
          recyclingStations,
        ),
        MapEntry(
          'Solar / renewable grid battery power',
          renewableEnergy,
        ),
        MapEntry(
          '24/7 Safe-space awareness team & SDG 16 charter',
          safeSpaceStewards,
        ),
        MapEntry(
          'Local NGO & regional supplier partnerships',
          localEcoPartners,
        ),
      ];

  int get totalCommitmentsMet =>
      checklistItems.where((entry) => entry.value).length;

  int get ecoScorePercentage =>
      ((totalCommitmentsMet / checklistItems.length) * 100).round();

  Map<String, dynamic> toJson() {
    return {
      'freeDrinkingWater': freeDrinkingWater,
      'firstAidAndQuietZone': firstAidAndQuietZone,
      'publicTransportIncluded': publicTransportIncluded,
      'bicycleParking': bicycleParking,
      'reusableCupsOnly': reusableCupsOnly,
      'recyclingStations': recyclingStations,
      'renewableEnergy': renewableEnergy,
      'safeSpaceStewards': safeSpaceStewards,
      'localEcoPartners': localEcoPartners,
      'waterPointsCount': waterPointsCount,
      'firstAidStationsCount': firstAidStationsCount,
      'recyclingPointsCount': recyclingPointsCount,
    };
  }

  factory EcoCommitments.fromJson(Map<String, dynamic> json) {
    return EcoCommitments(
      freeDrinkingWater: json['freeDrinkingWater'] as bool? ?? true,
      firstAidAndQuietZone: json['firstAidAndQuietZone'] as bool? ?? true,
      publicTransportIncluded: json['publicTransportIncluded'] as bool? ?? true,
      bicycleParking: json['bicycleParking'] as bool? ?? true,
      reusableCupsOnly: json['reusableCupsOnly'] as bool? ?? true,
      recyclingStations: json['recyclingStations'] as bool? ?? true,
      renewableEnergy: json['renewableEnergy'] as bool? ?? true,
      safeSpaceStewards: json['safeSpaceStewards'] as bool? ?? true,
      localEcoPartners: json['localEcoPartners'] as bool? ?? true,
      waterPointsCount: json['waterPointsCount'] as int? ?? 8,
      firstAidStationsCount: json['firstAidStationsCount'] as int? ?? 3,
      recyclingPointsCount: json['recyclingPointsCount'] as int? ?? 24,
    );
  }
}

enum MapPinCategory {
  water('Free Water', Icons.water_drop_rounded, Color(0xFF00E5FF)),
  firstAid('First Aid', Icons.medical_services_rounded, Color(0xFFFF2E93)),
  quietZone('Quiet Zone', Icons.self_improvement_rounded, Color(0xFFA855F7)),
  stage('Stages', Icons.music_note_rounded, Color(0xFFFF8A00)),
  recycling('Cups & Recycle', Icons.recycling_rounded, Color(0xFF10B981)),
  toilet('Toilets', Icons.wc_rounded, Color(0xFF38BDF8)),
  bikeParking('Bike & Shuttle', Icons.pedal_bike_rounded, Color(0xFFFBBF24));

  const MapPinCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class MapPinPoint {
  const MapPinPoint({
    required this.id,
    required this.title,
    required this.category,
    required this.x,
    required this.y,
    required this.subtitle,
    this.statusBadge = 'Open • No wait',
  });

  final String id;
  final String title;
  final MapPinCategory category;
  final double x;
  final double y;
  final String subtitle;
  final String statusBadge;
}

enum PersonalPinType {
  tent('My Tent', Icons.holiday_village_rounded, Color(0xFF10B981)),
  car('Parked Car', Icons.directions_car_filled_rounded, Color(0xFF3B82F6)),
  bike('My Bicycle', Icons.pedal_bike_rounded, Color(0xFFF59E0B)),
  meetup('Friend Meetup', Icons.groups_rounded, Color(0xFFFF2E93));

  const PersonalPinType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class PersonalSavedPin {
  const PersonalSavedPin({
    required this.type,
    required this.zoneLabel,
    required this.note,
    required this.savedAt,
    required this.x,
    required this.y,
    this.latitude = 51.4512,
    this.longitude = 5.4564,
  });

  final PersonalPinType type;
  final String zoneLabel;
  final String note;
  final DateTime savedAt;
  final double x;
  final double y;
  final double latitude;
  final double longitude;
}

class StageSlot {
  const StageSlot({
    required this.id,
    required this.artist,
    required this.stageName,
    required this.dayLabel,
    required this.timeRange,
    required this.genre,
    this.isSolarStage = true,
  });

  final String id;
  final String artist;
  final String stageName;
  final String dayLabel;
  final String timeRange;
  final String genre;
  final bool isSolarStage;
}

class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.tagline,
    required this.categoryLabel,
    required this.dates,
    required this.city,
    required this.venueAddress,
    required this.distanceKm,
    required this.priceEur,
    required this.ticketsSoldInApp,
    required this.capacity,
    required this.genres,
    required this.howToGetThere,
    required this.publicTransportInfo,
    required this.festivalTransportOffer,
    required this.organizerName,
    required this.ecoCommitments,
    required this.lineup,
    required this.mapPins,
    required this.primaryColor,
    required this.secondaryColor,
    this.isApprovedByAdmin = true,
    this.latitude = 51.4416,
    this.longitude = 5.4697,
    this.coverImageLabel = 'Neon Laser Mainstage Cover',
    this.coverIcon = Icons.wb_iridescent_rounded,
    this.bannerImagePath,
    this.isAiIngested = false,
    this.aiSourceUrl,
    this.aiVerificationScore = 0.95,
    this.aiVerificationReport,
    this.socialMediaVerification,
  });

  final String id;
  final String name;
  final String tagline;
  final String categoryLabel;
  final String dates;
  final String city;
  final String venueAddress;
  final int distanceKm;
  final double priceEur;
  final int ticketsSoldInApp;
  final int capacity;
  final List<String> genres;
  final String howToGetThere;
  final String publicTransportInfo;
  final String festivalTransportOffer;
  final String organizerName;
  final EcoCommitments ecoCommitments;
  final List<StageSlot> lineup;
  final List<MapPinPoint> mapPins;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isApprovedByAdmin;
  final double latitude;
  final double longitude;
  final String coverImageLabel;
  final IconData coverIcon;
  final String? bannerImagePath; // Local file path or asset URI for custom uploaded banner
  final bool isAiIngested;
  final String? aiSourceUrl;
  final double aiVerificationScore;
  final String? aiVerificationReport;
  final Map<String, bool>? socialMediaVerification; // e.g. {'instagram': true, 'facebook': true, 'tiktok': true}

  Festival copyWith({
    String? name,
    String? tagline,
    String? categoryLabel,
    String? dates,
    String? city,
    String? venueAddress,
    int? distanceKm,
    double? priceEur,
    int? ticketsSoldInApp,
    int? capacity,
    List<String>? genres,
    String? howToGetThere,
    String? publicTransportInfo,
    String? festivalTransportOffer,
    String? organizerName,
    bool? isApprovedByAdmin,
    double? latitude,
    double? longitude,
    EcoCommitments? ecoCommitments,
    String? coverImageLabel,
    IconData? coverIcon,
    String? bannerImagePath,
    bool? isAiIngested,
    String? aiSourceUrl,
    double? aiVerificationScore,
    String? aiVerificationReport,
    Map<String, bool>? socialMediaVerification,
  }) {
    return Festival(
      id: id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      dates: dates ?? this.dates,
      city: city ?? this.city,
      venueAddress: venueAddress ?? this.venueAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      priceEur: priceEur ?? this.priceEur,
      ticketsSoldInApp: ticketsSoldInApp ?? this.ticketsSoldInApp,
      capacity: capacity ?? this.capacity,
      genres: genres ?? this.genres,
      howToGetThere: howToGetThere ?? this.howToGetThere,
      publicTransportInfo: publicTransportInfo ?? this.publicTransportInfo,
      festivalTransportOffer:
          festivalTransportOffer ?? this.festivalTransportOffer,
      organizerName: organizerName ?? this.organizerName,
      ecoCommitments: ecoCommitments ?? this.ecoCommitments,
      lineup: lineup,
      mapPins: mapPins,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      isApprovedByAdmin: isApprovedByAdmin ?? this.isApprovedByAdmin,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coverImageLabel: coverImageLabel ?? this.coverImageLabel,
      coverIcon: coverIcon ?? this.coverIcon,
      bannerImagePath: bannerImagePath ?? this.bannerImagePath,
      isAiIngested: isAiIngested ?? this.isAiIngested,
      aiSourceUrl: aiSourceUrl ?? this.aiSourceUrl,
      aiVerificationScore: aiVerificationScore ?? this.aiVerificationScore,
      aiVerificationReport: aiVerificationReport ?? this.aiVerificationReport,
      socialMediaVerification:
          socialMediaVerification ?? this.socialMediaVerification,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'categoryLabel': categoryLabel,
      'dates': dates,
      'city': city,
      'venueAddress': venueAddress,
      'distanceKm': distanceKm,
      'priceEur': priceEur,
      'ticketsSoldInApp': ticketsSoldInApp,
      'capacity': capacity,
      'genres': genres,
      'howToGetThere': howToGetThere,
      'publicTransportInfo': publicTransportInfo,
      'festivalTransportOffer': festivalTransportOffer,
      'organizerName': organizerName,
      'ecoCommitments': ecoCommitments.toJson(),
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'isApprovedByAdmin': isApprovedByAdmin,
      'latitude': latitude,
      'longitude': longitude,
      'coverImageLabel': coverImageLabel,
      'coverIconCodePoint': coverIcon.codePoint,
      'bannerImagePath': bannerImagePath,
      'isAiIngested': isAiIngested,
      'aiSourceUrl': aiSourceUrl,
      'aiVerificationScore': aiVerificationScore,
    };
  }

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String? ?? '',
      categoryLabel: json['categoryLabel'] as String? ?? 'Music & Arts',
      dates: json['dates'] as String? ?? 'Summer 2027',
      city: json['city'] as String? ?? 'Netherlands',
      venueAddress: json['venueAddress'] as String? ?? 'Festival Grounds',
      distanceKm: json['distanceKm'] as int? ?? 25,
      priceEur: (json['priceEur'] as num?)?.toDouble() ?? 65.0,
      ticketsSoldInApp: json['ticketsSoldInApp'] as int? ?? 1,
      capacity: json['capacity'] as int? ?? 5000,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Electronic'],
      howToGetThere: json['howToGetThere'] as String? ?? 'Public transport available',
      publicTransportInfo: json['publicTransportInfo'] as String? ?? 'Free festival shuttle link',
      festivalTransportOffer: json['festivalTransportOffer'] as String? ?? 'Free bicycle parking',
      organizerName: json['organizerName'] as String? ?? 'Festival Organization',
      ecoCommitments: json['ecoCommitments'] != null
          ? EcoCommitments.fromJson(json['ecoCommitments'] as Map<String, dynamic>)
          : const EcoCommitments(
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
      primaryColor: Color(json['primaryColor'] as int? ?? 0xFF7C3AED),
      secondaryColor: Color(json['secondaryColor'] as int? ?? 0xFFFF2E93),
      isApprovedByAdmin: json['isApprovedByAdmin'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 51.4416,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 5.4697,
      coverImageLabel: json['coverImageLabel'] as String? ?? 'Custom Cover',
      coverIcon: Icons.wb_iridescent_rounded,
      bannerImagePath: json['bannerImagePath'] as String?,
      isAiIngested: json['isAiIngested'] as bool? ?? false,
      aiSourceUrl: json['aiSourceUrl'] as String?,
      aiVerificationScore: (json['aiVerificationScore'] as num?)?.toDouble() ?? 0.95,
      lineup: const [
        StageSlot(
          id: 'slot_1',
          artist: 'Headliner Live Set',
          stageName: 'Main Arena',
          dayLabel: 'Saturday',
          timeRange: '20:00 – 22:00',
          genre: 'Electronic',
        ),
      ],
      mapPins: const [
        MapPinPoint(
          id: 'pin_w1',
          title: 'Free Water Refill #1',
          category: MapPinCategory.water,
          x: 0.35,
          y: 0.40,
          subtitle: 'Free chilled water taps',
        ),
        MapPinPoint(
          id: 'pin_fa1',
          title: 'First Aid & Medical Tent',
          category: MapPinCategory.firstAid,
          x: 0.65,
          y: 0.55,
          subtitle: '24/7 Red Cross certified medics',
        ),
      ],
    );
  }
}

class RecommendationResult {
  const RecommendationResult({
    required this.festival,
    required this.matchPercentage,
    required this.reasons,
    required this.genreMatchScore,
    required this.ecoMatchScore,
    required this.distanceMatchScore,
  });

  final Festival festival;
  final int matchPercentage;
  final List<String> reasons;
  final int genreMatchScore;
  final int ecoMatchScore;
  final int distanceMatchScore;
}

class UserTicket {
  const UserTicket({
    required this.ticketId,
    required this.festivalId,
    required this.festivalName,
    required this.dates,
    required this.city,
    required this.ownerEmail,
    required this.ownerName,
    required this.purchasedAt,
    required this.securityHash,
    required this.includesFreeShuttlePass,
    required this.reusableCupTokenIncluded,
  });

  final String ticketId;
  final String festivalId;
  final String festivalName;
  final String dates;
  final String city;
  final String ownerEmail;
  final String ownerName;
  final DateTime purchasedAt;
  final String securityHash;
  final bool includesFreeShuttlePass;
  final bool reusableCupTokenIncluded;
}

class FacilityOrClaimReport {
  const FacilityOrClaimReport({
    required this.id,
    required this.festivalId,
    required this.festivalName,
    required this.reporterEmail,
    required this.issueType,
    required this.description,
    required this.createdAt,
    this.status = 'Pending Admin Verification',
  });

  final String id;
  final String festivalId;
  final String festivalName;
  final String reporterEmail;
  final String issueType;
  final String description;
  final DateTime createdAt;
  final String status;

  FacilityOrClaimReport copyWith({String? status}) {
    return FacilityOrClaimReport(
      id: id,
      festivalId: festivalId,
      festivalName: festivalName,
      reporterEmail: reporterEmail,
      issueType: issueType,
      description: description,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

class SecurityAuditEntry {
  const SecurityAuditEntry({
    required this.timestamp,
    required this.category,
    required this.actor,
    required this.action,
    required this.severity,
  });

  final DateTime timestamp;
  final String category;
  final String actor;
  final String action;
  final String severity;
}

// =============================================================================
// SOCIAL / FRIENDS / GROUPS / LIVE LOCATION SHARING MODELS
// =============================================================================
class BuddyFriend {
  BuddyFriend({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarColor,
    required this.statusText,
    this.isAddedFriend = true,
    this.sharedLocation,
    this.latitude = 51.4510,
    this.longitude = 5.4565,
    this.venueX = 0.38,
    this.venueY = 0.30,
  });

  final String id;
  final String name;
  final String username;
  final Color avatarColor;
  final String statusText;
  bool isAddedFriend;
  String? sharedLocation;
  final double latitude;
  final double longitude;
  final double venueX;
  final double venueY;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.isMe,
    required this.text,
    required this.timestamp,
    this.sharedLocationLabel,
  });

  final String id;
  final String senderName;
  final bool isMe;
  final String text;
  final DateTime timestamp;
  final String? sharedLocationLabel;
}

class FriendGroup {
  FriendGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.messages,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final List<ChatMessage> messages;
}

// =============================================================================
// SYSTEM ANNOUNCEMENT MODEL
// =============================================================================
class SystemAnnouncement {
  const SystemAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.category, // e.g. 'Maintenance', 'Festival Update', 'Important Notice'
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory SystemAnnouncement.fromJson(Map<String, dynamic> json) => SystemAnnouncement(
    id: json['id'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    category: json['category'] as String? ?? 'Important Notice',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    isActive: json['isActive'] == true || json['isActive'] == 1,
  );
}

// =============================================================================
// IN-APP NOTIFICATION MODEL (FOR SIMULATED PUSH NOTIFICATIONS)
// =============================================================================
class InAppPushNotification {
  const InAppPushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.targetRole, // 'visitor', 'organizer', 'all'
    required this.timestamp,
    this.relatedFestivalId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String targetRole;
  final DateTime timestamp;
  final String? relatedFestivalId;
  final bool isRead;
}
class OrganizerKvkVerification {
  const OrganizerKvkVerification({
    required this.companyName,
    required this.kvkNumber,
    required this.vatNumber,
    required this.businessAddress,
    required this.phone,
    required this.govIdType,
    required this.govIdDocumentNumber,
    required this.govIdFileName,
    required this.verifiedAt,
  });

  final String companyName;
  final String kvkNumber;
  final String vatNumber;
  final String businessAddress;
  final String phone;
  final String govIdType; // 'Dutch Passport', 'EU National ID Card', 'Driver License'
  final String govIdDocumentNumber;
  final String govIdFileName;
  final DateTime verifiedAt;
}
