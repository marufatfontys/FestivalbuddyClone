import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/festival_models.dart';
import '../services/app_state.dart';
import '../services/sample_data.dart';
import 'festival_detail_screen.dart';
import 'friends_chat_screen.dart';
import 'profile_security_screen.dart';
import 'settings_personalize_sheet.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  // 0 = Discover, 1 = Tickets, 2 = Friends, 3 = Profile (4 = 3-dot Settings menu trigger)
  int _currentIndex = 0;
  late final PageController _pageController;
  final _searchCtrl = TextEditingController();
  String? _selectedGenreFilter;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowAnnouncementPopup();
    });
  }

  void _checkAndShowAnnouncementPopup() {
    final pending = widget.appState.pendingAnnouncements;
    if (pending.isNotEmpty && mounted) {
      final announcement = pending.first;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF2E93),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      announcement.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            announcement.message,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.appState.dismissAnnouncement(announcement.id);
              },
              child: const Text('Got it!'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNotificationsSheet(BuildContext context) {
    final appState = widget.appState;
    final role = appState.isOrganizerAuthenticated ? 'organizer' : 'visitor';
    final userNotifs = appState.notifications
        .where((n) => n.targetRole == role || n.targetRole == 'all')
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF2E93), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Push Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: userNotifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No notifications right now',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == 'organizer'
                                ? 'You will be notified when your festival or account is approved.'
                                : 'You will be notified when newly approved festivals drop!',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: userNotifs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final notif = userNotifs[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${notif.timestamp.hour.toString().padLeft(2, '0')}:${notif.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.body,
                                style: const TextStyle(fontSize: 12.5, height: 1.4),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFestivalDetails(Festival festival, {int initialTab = 0}) {
    widget.appState.recordUserActivity();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FestivalDetailScreen(
          appState: widget.appState,
          festivalId: festival.id,
          initialTab: initialTab,
        ),
      ),
    );
  }

  void _openThreeDotSettingsMenu() {
    SettingsPersonalizeSheet.show(
      context,
      widget.appState,
      onApplyPersonalizedFeed: () {
        setState(() => _currentIndex = 0);
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final isOrganizer = appState.isOrganizerAuthenticated || appState.activeRole == UserRole.organizer;
    final showCommunity = appState.canShowCommunityTab;

    final bodyChildren = <Widget>[
      isOrganizer
          ? _buildOrganizerPublishedTab(context)
          : _buildSimpleVisualDiscoverTab(context),
      _buildSavedAndTicketsTab(context),
      if (showCommunity) FriendsChatScreen(appState: appState),
      ProfileSecurityScreen(appState: appState),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(isOrganizer ? Icons.inventory_2_outlined : Icons.local_fire_department_outlined),
        selectedIcon: Icon(isOrganizer ? Icons.inventory_2_rounded : Icons.local_fire_department_rounded),
        label: isOrganizer ? 'Published' : 'Discover',
      ),
      const NavigationDestination(
        icon: Icon(Icons.confirmation_number_outlined),
        selectedIcon: Icon(Icons.confirmation_number_rounded),
        label: 'Tickets',
      ),
      if (showCommunity)
        const NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded),
          label: 'Community',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz_rounded),
        selectedIcon: Icon(Icons.more_horiz_rounded),
        label: 'More',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E93).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.equalizer_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Festival Buddy',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Push Notifications Bell Icon
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: appState.notifications.any((n) {
                final role = appState.isOrganizerAuthenticated ? 'organizer' : 'visitor';
                return n.targetRole == role || n.targetRole == 'all';
              }),
              child: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            onPressed: () => _openNotificationsSheet(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                final profileIdx = showCommunity ? 3 : 2;
                setState(() => _currentIndex = profileIdx);
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    profileIdx,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      appState.isOrganizerAuthenticated
                          ? Icons.verified_rounded
                          : appState.isVisitorAuthenticated
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                      size: 15,
                      color: (appState.isOrganizerAuthenticated ||
                              appState.isVisitorAuthenticated)
                          ? Theme.of(context).colorScheme.tertiary
                          : null,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      appState.isOrganizerAuthenticated
                          ? 'Organizer'
                          : appState.isVisitorAuthenticated
                              ? 'Visitor'
                              : 'Guest',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          setState(() => _currentIndex = page);
          appState.recordUserActivity();
        },
        children: bodyChildren,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: (idx) {
          appState.recordUserActivity();
          if (idx == destinations.length - 1) {
            // 3-dot clickable button at the bottom right opens Settings & Personalize menu
            _openThreeDotSettingsMenu();
            return;
          }
          setState(() => _currentIndex = idx);
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              idx,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
            );
          }
        },
        destinations: destinations,
      ),
    );
  }

  // ============================================================================
  // TAB 1 (ORGANIZER VIEW): "PUBLISHED" TAB SHOWING ALL PUBLISHED & PENDING FESTIVALS
  // ============================================================================
  Widget _buildOrganizerPublishedTab(BuildContext context) {
    final appState = widget.appState;
    final allFestivals = appState.allFestivals;

    // Filter festivals owned or published by this organizer
    final orgName = appState.organizerName.toLowerCase();
    final orgFestivals = allFestivals.where((f) {
      return f.organizerName.toLowerCase().contains(orgName) ||
          f.id.contains('custom') ||
          f.id.contains('fest_greenpulse');
    }).toList();

    final approved = orgFestivals.where((f) => f.isApprovedByAdmin).toList();
    final pending = orgFestivals.where((f) => !f.isApprovedByAdmin).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await appState.refreshFromBackend();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stadium_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.organizerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${approved.length} Live on Discovery • ${pending.length} Pending Approval',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pending Approvals Section
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pending Admin Approval (${pending.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All your festivals have been approved and published to the public Discover feed!',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...pending.map(
              (f) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.amber),
                  ),
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${f.city} • ${f.dates} • €${f.priceEur.toStringAsFixed(0)}\nStatus: Awaiting Admin Verification',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Live Published Section
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'Live Published Festivals (${approved.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (approved.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No published festivals yet. Submit a new event to publish!',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            ...approved.map(
              (f) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  onTap: () => _openFestivalDetails(f),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: f.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f.coverIcon, color: f.primaryColor),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Public Live',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${f.city} • ${f.dates} • €${f.priceEur.toStringAsFixed(0)} • ${f.ticketsSoldInApp} tickets reserved',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: CLEAN, FLASHY VISUAL DISCOVERY FEED (WITH PERSONALIZED VIEW SUPPORT)
  // ============================================================================
  Widget _buildSimpleVisualDiscoverTab(BuildContext context) {
    final appState = widget.appState;
    final cleanQuery = AppState.sanitizeAndValidateInput(
      _searchCtrl.text,
      maxLength: 80,
    ).toLowerCase();

    final rankedRecommendations = appState.getRecommendedFestivals().where((rec) {
      final f = rec.festival;
      if (cleanQuery.isNotEmpty) {
        final matchesBasic =
            '${f.name} ${f.city} ${f.categoryLabel}'.toLowerCase().contains(cleanQuery);
        final matchesLineupArtist =
            f.lineup.any((slot) => slot.artist.toLowerCase().contains(cleanQuery));
        if (!matchesBasic && !matchesLineupArtist) return false;
      }
      if (_selectedGenreFilter != null &&
          !f.genres.contains(_selectedGenreFilter)) {
        return false;
      }

      // Personalized Discovery Filter (configured from the 3-dot bottom-right button)
      if (appState.isPersonalizedDiscoveryEnabled) {
        final matchesGenre =
            f.genres.any((g) => appState.selectedGenres.contains(g));
        final matchesCity = appState.preferredDiscoveryCity == 'All Cities' ||
            f.city
                .toLowerCase()
                .contains(appState.preferredDiscoveryCity.toLowerCase());
        final matchesDistance =
            f.distanceKm <= appState.maxPreferredDistanceKm;
        if (!matchesGenre || !matchesCity || !matchesDistance) {
          return false;
        }
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await widget.appState.refreshFromBackend();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
        // Sleek Search Bar (Festivals, Cities & Artist Lineups)
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search festivals, artists, or cities...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded),
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),

        // Personalized Discovery Active Banner (when enabled via 3-dot menu)
        if (appState.isPersonalizedDiscoveryEnabled) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  const Color(0xFFFF2E93).withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF2E93).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Color(0xFFFF2E93),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Personalized: ${appState.preferredDiscoveryCity} • ≤${appState.maxPreferredDistanceKm.round()} km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      appState.setPersonalizedDiscovery(enabled: false),
                  child: const Text('Show All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Simple Genre Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildVibePill(
                context,
                label: '🔥 All Festivals',
                isSelected: _selectedGenreFilter == null,
                onTap: () => setState(() => _selectedGenreFilter = null),
              ),
              ...SampleData.allGenres.map(
                (genre) => _buildVibePill(
                  context,
                  label: genre.split(' ').first,
                  isSelected: _selectedGenreFilter == genre,
                  onTap: () => setState(() {
                    _selectedGenreFilter =
                        _selectedGenreFilter == genre ? null : genre;
                  }),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        if (rankedRecommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 40,
                    color: Color(0xFFA855F7),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No festivals match your custom filter',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() => _selectedGenreFilter = null);
                      appState.setPersonalizedDiscovery(enabled: false);
                    },
                    child: const Text('Reset Personalized Filter'),
                  ),
                ],
              ),
            ),
          ),

        // Scrollable Feed of Flashy Visual Festival Cards
        ...rankedRecommendations.map(
          (rec) => _buildVisualFestivalThumbnailCard(context, rec),
        ),
      ],
    ),
  );
}

  Widget _buildVibePill(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                  )
                : null,
            color: isSelected
                ? null
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualFestivalThumbnailCard(
    BuildContext context,
    RecommendationResult rec,
  ) {
    final festival = rec.festival;
    final isFav = widget.appState.isFavorite(festival.id);
    final cleanQuery = AppState.sanitizeAndValidateInput(
      _searchCtrl.text,
      maxLength: 80,
    ).toLowerCase();
    final matchingArtists = cleanQuery.isEmpty
        ? <String>[]
        : festival.lineup
            .where((s) => s.artist.toLowerCase().contains(cleanQuery))
            .map((s) => s.artist)
            .toList();

    return GestureDetector(
      onTap: () => _openFestivalDetails(festival),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: festival.primaryColor.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: festival.primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual Thumbnail Poster (185px height)
            SizedBox(
              height: 185,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (festival.bannerImagePath != null)
                    festival.bannerImagePath!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(festival.bannerImagePath!.split(',').last),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: festival.primaryColor.withValues(alpha: 0.3),
                              child: Icon(festival.coverIcon, color: festival.primaryColor, size: 40),
                            ),
                          )
                        : (kIsWeb || festival.bannerImagePath!.startsWith('http'))
                            ? Image.network(
                                festival.bannerImagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: festival.primaryColor.withValues(alpha: 0.3),
                                  child: Icon(festival.coverIcon, color: festival.primaryColor, size: 40),
                                ),
                              )
                            : Image.file(
                                File(festival.bannerImagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: festival.primaryColor.withValues(alpha: 0.3),
                                  child: Icon(festival.coverIcon, color: festival.primaryColor, size: 40),
                                ),
                              )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            festival.primaryColor,
                            festival.secondaryColor,
                            const Color(0xFF0D0B18),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _FestivalThumbnailPosterPainter(
                          seed: festival.id.hashCode,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left: Date Badge
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            festival.coverIcon,
                            color: const Color(0xFF00E5FF),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            festival.dates,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right: Heart Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => widget.appState.toggleFavorite(festival.id),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                              isFav ? const Color(0xFFFF2E93) : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Bottom of Thumbnail: Festival Name
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          festival.categoryLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          festival.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // If user searched for an artist and it matched this festival's lineup, highlight it!
            if (matchingArtists.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      size: 15,
                      color: Color(0xFFFF2E93),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Lineup Match: ${matchingArtists.join(", ")}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Minimal Visual Footer: Location, Eco Badge & Attendance Only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Color(0xFFFF2E93),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${festival.city} • ${festival.distanceKm} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.eco_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${festival.ecoCommitments.ecoScorePercentage}% Eco',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.people_alt_rounded,
                    size: 15,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${festival.ticketsSoldInApp} going',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTicketFullScreenModal(UserTicket ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildTicketFullScreenView(ctx, ticket),
    );
  }

  Widget _buildTicketFullScreenView(BuildContext ctx, UserTicket ticket) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    final fest = widget.appState.allFestivals.firstWhere(
      (f) => f.id == ticket.festivalId,
      orElse: () => widget.appState.allFestivals.first,
    );

    return Container(
      height: MediaQuery.of(ctx).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131124) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Official Digital Pass',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Ticket Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                // Top Visual Header Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [fest.primaryColor, fest.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: fest.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (fest.bannerImagePath != null)
                        Positioned.fill(
                          child: fest.bannerImagePath!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(fest.bannerImagePath!.split(',').last),
                                  fit: BoxFit.cover,
                                )
                              : (kIsWeb || fest.bannerImagePath!.startsWith('http'))
                                  ? Image.network(fest.bannerImagePath!, fit: BoxFit.cover)
                                  : Image.file(File(fest.bannerImagePath!), fit: BoxFit.cover),
                        ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: fest.bannerImagePath != null
                              ? LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'VERIFIED ADMISSION',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          Text(
                            ticket.dates,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        ticket.festivalName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pass ID: ${ticket.ticketId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

                const SizedBox(height: 24),

                // Large Central QR Code Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _TicketQrCodePainter(seed: ticket.ticketId.hashCode),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'HOLD NEAR GATE SCANNER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Attendee Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendee Name',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            ticket.ownerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shuttle Pass Included',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            ticket.includesFreeShuttlePass ? 'Yes (Unlimited) ✓' : 'Standard',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reusable Cup Token',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            ticket.reusableCupTokenIncluded ? '1x Token Linked ✓' : 'None',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Venue & Location Details Section at Bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: Color(0xFFFF2E93), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Venue & Location Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fest.venueAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fest.city} • ${fest.publicTransportInfo}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: TICKETS & SAVED FESTIVALS
  // ============================================================================
  Widget _buildSavedAndTicketsTab(BuildContext context) {
    final appState = widget.appState;
    final savedFestivals = appState.approvedFestivals
        .where((f) => appState.isFavorite(f.id))
        .toList();
    final myTickets = appState.currentUserTickets;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(
          'My Tickets',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (myTickets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 44,
                    color: Color(0xFFA855F7),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No festival passes yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap any festival in Discover and click "Get Ticket" to add your pass here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ...myTickets.map(
            (tkt) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _openTicketFullScreenModal(tkt),
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                title: Text(
                  tkt.festivalName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text('${tkt.dates} • ${tkt.city}\nPass ID: ${tkt.ticketId}'),
                trailing: const Icon(Icons.fullscreen_rounded, size: 24),
                isThreeLine: true,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Saved Festivals (${savedFestivals.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        ...savedFestivals.map(
          (fest) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: fest.primaryColor,
                child:
                    const Icon(Icons.music_note_rounded, color: Colors.white),
              ),
              title: Text(
                fest.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${fest.dates} • ${fest.city}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openFestivalDetails(fest),
            ),
          ),
        ),
      ],
    );
  }
}

class _FestivalThumbnailPosterPainter extends CustomPainter {
  const _FestivalThumbnailPosterPainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.25),
      70,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.7),
      50,
      glowPaint,
    );

    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (double x = 24; x < size.width - 24; x += 12) {
      final barH = 12.0 + rnd.nextDouble() * 48.0;
      canvas.drawLine(
        Offset(x, size.height * 0.55 - barH / 2),
        Offset(x, size.height * 0.55 + barH / 2),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FestivalThumbnailPosterPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _TicketQrCodePainter extends CustomPainter {
  const _TicketQrCodePainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1B4B)
      ..style = PaintingStyle.fill;

    final cellW = size.width / 16;
    final cellH = size.height / 16;
    final rnd = Random(seed);

    void drawMarker(double startX, double startY) {
      canvas.drawRect(Rect.fromLTWH(startX, startY, cellW * 4, cellH * 4), paint);
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(startX + cellW, startY + cellH, cellW * 2, cellH * 2), whitePaint);
      canvas.drawRect(Rect.fromLTWH(startX + cellW * 1.5, startY + cellH * 1.5, cellW, cellH), paint);
    }

    drawMarker(0, 0);
    drawMarker(size.width - cellW * 4, 0);
    drawMarker(0, size.height - cellH * 4);

    for (int r = 0; r < 16; r++) {
      for (int c = 0; c < 16; c++) {
        final inTopLeft = r < 5 && c < 5;
        final inTopRight = r < 5 && c > 10;
        final inBottomLeft = r > 10 && c < 5;
        if (!inTopLeft && !inTopRight && !inBottomLeft) {
          if (rnd.nextDouble() > 0.45) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellW + 1, r * cellH + 1, cellW - 2, cellH - 2),
                const Radius.circular(2),
              ),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TicketQrCodePainter oldDelegate) =>
      oldDelegate.seed != seed;
}
