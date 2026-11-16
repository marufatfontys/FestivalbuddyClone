import 'package:flutter/material.dart';
import '../models/festival_models.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';

class WebAdminDashboardScreen extends StatefulWidget {
  const WebAdminDashboardScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<WebAdminDashboardScreen> createState() => _WebAdminDashboardScreenState();
}

class _WebAdminDashboardScreenState extends State<WebAdminDashboardScreen> {
  int _selectedNavIndex = 0; // 0: Overview, 1: Festivals, 2: Organizers, 3: Reports, 4: Audit Logs
  String _festivalSearchQuery = '';
  String _organizerFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refreshBackendData();
  }

  void _refreshBackendData() async {
    // Sync backend festivals & organizers
    await ApiService.fetchFestivals();
    final remoteOrganizers = await ApiService.fetchOrganizers();
    if (mounted && remoteOrganizers.isNotEmpty) {
      for (final org in remoteOrganizers) {
        final email = org['email'] as String?;
        final isApproved = org['isApproved'] == true || org['isApproved'] == 1;
        final status = org['status'] as String? ?? (isApproved ? 'Approved' : 'Pending Review');
        if (email != null) {
          widget.appState.setOrganizerApproval(email, approved: isApproved, note: status);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.appState.isHighContrastNightMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0D1C) : const Color(0xFFF4F3FA),
      body: Row(
        children: [
          // Left Sidebar for Admin Navigation
          NavigationRail(
            backgroundColor: isDark ? const Color(0xFF161426) : Colors.white,
            extended: isWide,
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: (idx) => setState(() => _selectedNavIndex = idx),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Festival Buddy',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          'Web Admin Console',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: IconButton(
                    tooltip: 'Toggle Night Mode',
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    onPressed: () => widget.appState.toggleNightMode(),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.festival_outlined),
                selectedIcon: Icon(Icons.festival_rounded),
                label: Text('Festival Control'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user_rounded),
                label: Text('Organizer Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign_rounded),
                label: Text('Announcements'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_problem_outlined),
                selectedIcon: Icon(Icons.report_problem_rounded),
                label: Text('Visitor Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lock_clock_outlined),
                selectedIcon: Icon(Icons.lock_clock_rounded),
                label: Text('Audit Logs'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main Admin Content Area
          Expanded(
            child: Column(
              children: [
                // Top Admin App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161426) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E0FF),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getSectionTitle(_selectedNavIndex),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Chip(
                        avatar: const CircleAvatar(
                          backgroundColor: Color(0xFF10B981),
                          radius: 5,
                        ),
                        label: const Text('Backend API: Online (Port 3000)', style: TextStyle(fontSize: 11.5)),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 6),
                            Text(
                              widget.appState.currentUserEmail ?? 'admin@festivalbuddy.nl',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Selected Tab View
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: switch (_selectedNavIndex) {
                      0 => _buildOverviewSection(context),
                      1 => _buildFestivalsSection(context),
                      2 => _buildOrganizersSection(context),
                      3 => _buildAnnouncementsSection(context),
                      4 => _buildReportsSection(context),
                      _ => _buildAuditLogsSection(context),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionTitle(int index) {
    return switch (index) {
      0 => 'Executive Administration Overview',
      1 => 'Festival Management & Moderation',
      2 => 'Organizer Verification & Sign-up Queue',
      3 => 'Global System Announcements & In-App Popups',
      4 => 'SDG Anti-Greenwashing & Safety Reports',
      _ => 'Security & Compliance Audit Logs',
    };
  }

  // ===========================================================================
  // SECTION 0: OVERVIEW METRICS
  // ===========================================================================
  Widget _buildOverviewSection(BuildContext context) {
    final state = widget.appState;
    final totalFestivals = state.allFestivals.length;
    final approvedFestivals = state.approvedFestivals.length;
    final pendingFestivals = state.pendingFestivals.length;
    final totalOrganizers = state.adminOrganizersQueue.length;
    final pendingOrganizers = state.adminOrganizersQueue.where((o) => o['isApproved'] != true).length;
    final totalReports = state.reports.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _metricCard(
                title: 'Total Festivals',
                value: '$totalFestivals',
                subtitle: '$approvedFestivals Live • $pendingFestivals Pending',
                icon: Icons.celebration_rounded,
                color: const Color(0xFF7C3AED),
              ),
              _metricCard(
                title: 'Organizer Sign-ups',
                value: '$totalOrganizers',
                subtitle: '$pendingOrganizers Pending KVK Verification',
                icon: Icons.business_center_rounded,
                color: const Color(0xFF00E5FF),
              ),
              _metricCard(
                title: 'Visitor Reports',
                value: '$totalReports',
                subtitle: 'Anti-Greenwashing & Water Audits',
                icon: Icons.shield_outlined,
                color: const Color(0xFFFF2E93),
              ),
              _metricCard(
                title: 'Security Audits',
                value: '${state.auditLogs.length}',
                subtitle: '100% Immutable Log Record',
                icon: Icons.policy_rounded,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Quick Action Control Center',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notification_important_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pending Organizer Applications ($pendingOrganizers)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dutch Chamber of Commerce (KVK) and government ID checks awaiting administrator decision.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _selectedNavIndex = 2),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Review Organizer Queue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Staged AI / New Listings ($pendingFestivals)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Festivals ready for SDG verification, editing details, or administrative deletion.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _selectedNavIndex = 1),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Manage Event Listings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = widget.appState.isHighContrastNightMode;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E0FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: FESTIVALS MANAGEMENT (EDIT, DELETE, APPROVE)
  // ===========================================================================
  Widget _buildFestivalsSection(BuildContext context) {
    final festivals = widget.appState.allFestivals.where((f) {
      if (_festivalSearchQuery.isEmpty) return true;
      final q = _festivalSearchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) ||
          f.city.toLowerCase().contains(q) ||
          f.organizerName.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search & Filter Toolbar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search festival by name, city, or organizer...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _festivalSearchQuery = val),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _openFestivalEditor(context, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Festival'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Festival Management Table
        Expanded(
          child: Card(
            child: festivals.isEmpty
                ? const Center(child: Text('No festivals found matching your search.'))
                : ListView.separated(
                    itemCount: festivals.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final fest = festivals[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: fest.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(fest.coverIcon, color: fest.primaryColor),
                        ),
                        title: Row(
                          children: [
                            Text(
                              fest.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            if (fest.isApprovedByAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Live on Discovery',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Pending Approval',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${fest.city} • ${fest.dates} • €${fest.priceEur.toStringAsFixed(0)} • Organizer: ${fest.organizerName}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!fest.isApprovedByAdmin)
                              IconButton(
                                tooltip: 'Approve Event for Discovery',
                                icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
                                onPressed: () {
                                  widget.appState.approveFestival(fest.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Approved "${fest.name}" for public listing!')),
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: 'Edit Event Details',
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                              onPressed: () => _openFestivalEditor(context, fest),
                            ),
                            IconButton(
                              tooltip: 'Delete / Remove Event',
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteFestival(context, fest),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteFestival(BuildContext context, Festival festival) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Event Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${festival.name}" from Festival Buddy?\n\nThis will remove the event from public discovery and delete it from the SQLite database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.appState.deleteFestival(festival.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Permanently removed "${festival.name}".')),
              );
            },
            child: const Text('Delete Event'),
          ),
        ],
      ),
    );
  }

  void _openFestivalEditor(BuildContext context, Festival? festival) {
    final isNew = festival == null;
    final nameCtrl = TextEditingController(text: festival?.name ?? '');
    final taglineCtrl = TextEditingController(text: festival?.tagline ?? '');
    final cityCtrl = TextEditingController(text: festival?.city ?? 'Eindhoven, NL');
    final venueCtrl = TextEditingController(text: festival?.venueAddress ?? 'Strijp-S, Eindhoven');
    final datesCtrl = TextEditingController(text: festival?.dates ?? '18–20 July 2027');
    final priceCtrl = TextEditingController(text: (festival?.priceEur ?? 65.0).toStringAsFixed(0));
    final capacityCtrl = TextEditingController(text: (festival?.capacity ?? 5000).toString());
    final distanceCtrl = TextEditingController(text: (festival?.distanceKm ?? 25).toString());

    bool water = festival?.ecoCommitments.freeDrinkingWater ?? true;
    bool firstAid = festival?.ecoCommitments.firstAidAndQuietZone ?? true;
    bool transit = festival?.ecoCommitments.publicTransportIncluded ?? true;
    bool cups = festival?.ecoCommitments.reusableCupsOnly ?? true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Create New Festival Listing' : 'Edit Festival: ${festival.name}'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Festival Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taglineCtrl,
                    decoration: const InputDecoration(labelText: 'Tagline / Short Pitch'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: datesCtrl,
                          decoration: const InputDecoration(labelText: 'Dates *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: venueCtrl,
                    decoration: const InputDecoration(labelText: 'Venue Address'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Ticket Price (€)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Capacity'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: distanceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Distance (km)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('SDG Sustainability Commitments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Free drinking water refill stations (SDG 3)'),
                    value: water,
                    onChanged: (v) => setDialogState(() => water = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('First Aid tents & Quiet zone (SDG 3)'),
                    value: firstAid,
                    onChanged: (v) => setDialogState(() => firstAid = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('100% Circular reusable cups (SDG 12)'),
                    value: cups,
                    onChanged: (v) => setDialogState(() => cups = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Public transit discount / shuttle included (SDG 11)'),
                    value: transit,
                    onChanged: (v) => setDialogState(() => transit = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final eco = EcoCommitments(
                  freeDrinkingWater: water,
                  firstAidAndQuietZone: firstAid,
                  publicTransportIncluded: transit,
                  bicycleParking: true,
                  reusableCupsOnly: cups,
                  recyclingStations: true,
                  renewableEnergy: true,
                  safeSpaceStewards: true,
                  localEcoPartners: true,
                );

                if (isNew) {
                  widget.appState.createFestivalListing(
                    name: nameCtrl.text.trim(),
                    tagline: taglineCtrl.text.trim(),
                    dates: datesCtrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    venueAddress: venueCtrl.text.trim(),
                    distanceKm: int.tryParse(distanceCtrl.text) ?? 25,
                    priceEur: double.tryParse(priceCtrl.text) ?? 65.0,
                    genres: ['Electronic & Techno', 'Live Music'],
                    howToGetThere: 'Direct transit access.',
                    publicTransportInfo: 'City trains & buses.',
                    festivalTransportOffer: 'Green shuttle available.',
                    ecoCommitments: eco,
                  );
                } else {
                  widget.appState.updateFestivalDetails(
                    festivalId: festival.id,
                    name: nameCtrl.text.trim(),
                    tagline: taglineCtrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    venueAddress: venueCtrl.text.trim(),
                    dates: datesCtrl.text.trim(),
                    priceEur: double.tryParse(priceCtrl.text),
                    capacity: int.tryParse(capacityCtrl.text),
                    distanceKm: int.tryParse(distanceCtrl.text),
                    ecoCommitments: eco,
                  );
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isNew ? 'Festival created successfully!' : 'Festival updated!')),
                );
              },
              child: Text(isNew ? 'Create Festival' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: ORGANIZER VERIFICATION & SIGN-UP QUEUE
  // ===========================================================================
  Widget _buildOrganizersSection(BuildContext context) {
    final allOrganizers = widget.appState.adminOrganizersQueue;
    final filtered = allOrganizers.where((o) {
      if (_organizerFilter == 'Pending') return o['isApproved'] != true;
      if (_organizerFilter == 'Approved') return o['isApproved'] == true;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Tabs
        Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All Organizers')),
                ButtonSegment(value: 'Pending', label: Text('Pending Review')),
                ButtonSegment(value: 'Approved', label: Text('Approved')),
              ],
              selected: {_organizerFilter},
              onSelectionChanged: (val) => setState(() => _organizerFilter = val.first),
            ),
            const Spacer(),
            Text(
              'Showing ${filtered.length} organizer accounts',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Organizers Table
        Expanded(
          child: Card(
            child: filtered.isEmpty
                ? const Center(child: Text('No organizers found for this filter.'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final org = filtered[idx];
                      final isApproved = org['isApproved'] == true;
                      final email = org['email'] as String? ?? 'N/A';
                      final company = org['companyName'] as String? ?? org['name'] as String? ?? 'Company';
                      final kvk = org['kvkNumber'] as String? ?? 'N/A';
                      final govId = org['govIdType'] as String? ?? 'Dutch Passport';
                      final docNum = org['govIdNumber'] as String? ?? 'DOC-XXXXXX';
                      final status = org['status'] as String? ?? (isApproved ? 'Approved' : 'Pending');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: isApproved ? const Color(0xFF10B981) : Colors.amber,
                          child: Icon(
                            isApproved ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isApproved ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isApproved ? const Color(0xFF10B981) : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Email: $email\nKVK Registration: $kvk • Identity Verification: $govId ($docNum)\nAddress: ${org["businessAddress"] ?? "Netherlands"} • Phone: ${org["phone"] ?? "N/A"}',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isApproved) ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                                onPressed: () {
                                  widget.appState.setOrganizerApproval(email, approved: true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Approved organizer account for $company!')),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Reject'),
                                onPressed: () {
                                  widget.appState.setOrganizerApproval(email, approved: false, note: 'Rejected: Incomplete Documentation');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Rejected application for $email.')),
                                  );
                                },
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.undo_rounded, size: 16),
                                label: const Text('Revoke Approval'),
                                onPressed: () {
                                  widget.appState.setOrganizerApproval(email, approved: false, note: 'Suspended by Admin');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Approval revoked for $company.')),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 3: SYSTEM ANNOUNCEMENTS (ONE-TIME IN-APP POPUP TO ALL USERS)
  // ===========================================================================
  Widget _buildAnnouncementsSection(BuildContext context) {
    final announcements = widget.appState.systemAnnouncements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In-App Global Announcements & Popups',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Announcements published here trigger a 1-time modal popup when any visitor or organizer opens the app. Once closed by the user, it automatically dismisses.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E93),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _openCreateAnnouncementDialog(context),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Post New Announcement'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            child: announcements.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No announcements currently active.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Post an announcement above to broadcast updates or maintenance alerts to all users.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: announcements.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final ann = announcements[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2E93).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF2E93), size: 24),
                        ),
                        title: Row(
                          children: [
                            Text(ann.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ann.category,
                                style: const TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${ann.message}\nPublished: ${ann.createdAt.toString().split(".")[0]}',
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete Announcement',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () {
                            widget.appState.deleteAdminAnnouncement(ann.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Announcement "${ann.title}" removed.')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _openCreateAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'Maintenance Break';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: Color(0xFFFF2E93)),
              SizedBox(width: 8),
              Text('Broadcast Announcement'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: const [
                    DropdownMenuItem(value: 'Maintenance Break', child: Text('Maintenance Break')),
                    DropdownMenuItem(value: 'System Update', child: Text('System Update')),
                    DropdownMenuItem(value: 'Festival Safety Alert', child: Text('Festival Safety Alert')),
                    DropdownMenuItem(value: 'Important Notice', child: Text('Important Notice')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Announcement Headline *',
                    hintText: 'e.g. Scheduled Cloud Maintenance at 02:00',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Broadcast Message *',
                    hintText: 'Explain the details clearly. This will be shown once in a popup dialog to all active mobile users.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2E93)),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                  return;
                }
                widget.appState.publishAdminAnnouncement(
                  title: titleCtrl.text.trim(),
                  message: messageCtrl.text.trim(),
                  category: category,
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement published to all users!')),
                );
              },
              child: const Text('Publish Announcement'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: VISITOR REPORTS (ANTI-GREENWASHING & SAFETY)
  // ===========================================================================
  Widget _buildReportsSection(BuildContext context) {
    final reports = widget.appState.reports;

    return Card(
      child: reports.isEmpty
          ? const Center(child: Text('No visitor reports submitted yet.'))
          : ListView.separated(
              itemCount: reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final rep = reports[idx];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFF2E93),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Text('${rep.festivalName} • ${rep.issueType}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(rep.status, style: const TextStyle(fontSize: 10.5)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${rep.description}\nReporter: ${rep.reporterEmail} • Submitted: ${rep.createdAt.toString().split(".")[0]}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          widget.appState.updateReportStatus(rep.id, 'Verified & Organizer Warned');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked as Verified & Organizer Warned')),
                          );
                        },
                        child: const Text('Flag Organizer', style: TextStyle(fontSize: 12)),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          widget.appState.updateReportStatus(rep.id, 'Resolved On-Site');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked report as Resolved On-Site')),
                          );
                        },
                        child: const Text('Resolve', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // SECTION 4: AUDIT LOGS
  // ===========================================================================
  Widget _buildAuditLogsSection(BuildContext context) {
    final logs = widget.appState.auditLogs;

    return Card(
      child: logs.isEmpty
          ? const Center(child: Text('No security audit logs recorded.'))
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final log = logs[idx];
                final color = switch (log.severity) {
                  'CRITICAL' => Colors.redAccent,
                  'WARN' => Colors.amber,
                  _ => const Color(0xFF10B981),
                };

                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.severity,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    '${log.category} • Actor: ${log.actor} • ${log.timestamp.toString().split(".")[0]}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}
