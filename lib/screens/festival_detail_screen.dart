import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/festival_models.dart';
import '../services/app_state.dart';
import 'companion_view.dart';
import '../widgets/festival_banner_image.dart';

class FestivalDetailScreen extends StatefulWidget {
  const FestivalDetailScreen({
    super.key,
    required this.appState,
    required this.festivalId,
    this.initialTab = 0,
  });

  final AppState appState;
  final String festivalId;
  final int initialTab;

  @override
  State<FestivalDetailScreen> createState() => _FestivalDetailScreenState();
}

class _FestivalDetailScreenState extends State<FestivalDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openTicketCheckoutSheet(Festival festival) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number_rounded, color: festival.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Get Festival Pass',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                festival.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${festival.dates} • ${festival.city}'),
              trailing: Text(
                '€${festival.priceEur.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(
                  avatar: Icon(Icons.directions_bus_rounded, size: 16),
                  label: Text('Free Shuttle Pass'),
                ),
                Chip(
                  avatar: Icon(Icons.local_drink_rounded, size: 16),
                  label: Text('1x Reusable Cup Token'),
                ),
                Chip(
                  avatar: Icon(Icons.qr_code_2_rounded, size: 16),
                  label: Text('Instant QR Pass'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E93),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final ticket =
                      widget.appState.purchaseTicketForCurrentUser(festival);
                  Navigator.pop(ctx);
                  _openTicketFullScreenPreview(context, ticket, festival);
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    'Confirm Pass • €${festival.priceEur.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTicketFullScreenPreview(
      BuildContext context, UserTicket ticket, Festival festival) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

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
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Pass Purchased Successfully!',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [festival.primaryColor, festival.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: festival.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                                  'OFFICIAL DIGITAL PASS',
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
                    const SizedBox(height: 24),
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
                              painter: _DetailTicketQrPainter(seed: ticket.ticketId.hashCode),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'READY TO SCAN AT GATE',
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
                            festival.venueAddress,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${festival.city} • ${festival.publicTransportInfo}',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final festival = widget.appState.allFestivals.firstWhere(
          (f) => f.id == widget.festivalId,
          orElse: () => widget.appState.allFestivals.first,
        );
        final isFav = widget.appState.isFavorite(festival.id);
        final recommendation = widget.appState
            .getRecommendedFestivals()
            .where((r) => r.festival.id == festival.id)
            .firstOrNull;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              festival.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: () => widget.appState.toggleFavorite(festival.id),
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFFF2E93) : null,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.auto_awesome_mosaic_rounded),
                  text: 'Overview',
                ),
                Tab(
                  icon: Icon(Icons.map_rounded),
                  text: 'Festival Map & Lineup',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, festival, recommendation),
              CompanionView(
                appState: widget.appState,
                festival: festival,
                showFestivalSelector: false,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '€${festival.priceEur.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          '${festival.ticketsSoldInApp} going on Festival Buddy',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E93),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _openTicketCheckoutSheet(festival),
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text(
                      'Get Ticket',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    Festival festival,
    RecommendationResult? recommendation,
  ) {
    final soldRatio =
        (festival.ticketsSoldInApp / festival.capacity).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        // Clean Hero Poster Banner Card
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [festival.primaryColor, festival.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: festival.primaryColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (festival.bannerImagePath != null)
                Positioned.fill(
                  child: buildFestivalBannerImage(festival.bannerImagePath, fit: BoxFit.cover),
                ),
              // Subtle top vignette for contrast
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 70,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Top Overlay: Only Date (Top Left) & Organizer Banner Change Button (Top Right)
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Only Date appears on top left
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            festival.dates,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Organizer-only Change Banner Button
                    if (widget.appState.activeRole == UserRole.organizer || widget.appState.activeRole == UserRole.admin)
                      IconButton.filledTonal(
                        tooltip: 'Change Festival Banner',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.photo_camera_rounded, size: 16),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 800,
                            imageQuality: 75,
                          );
                          if (img != null) {
                            widget.appState.updateFestivalBanner(festival.id, img.path);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Festival banner updated successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Festival Name, Music Genre, Location outside the card
        Text(
          festival.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: festival.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                festival.categoryLabel,
                style: TextStyle(
                  color: festival.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.location_on_rounded, size: 15, color: Colors.grey),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                '${festival.city} • ${festival.distanceKm} km away',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (festival.tagline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            festival.tagline,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Sustainable Perks: Single horizontal side-scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _compactPerkChip(
                icon: Icons.water_drop_rounded,
                color: const Color(0xFF00E5FF),
                label: 'Water Points',
                onTap: () => _showCommitmentDetailModal(
                  title: 'Free Fresh Drinking Water',
                  subtitle: '${festival.ecoCommitments.waterPointsCount} clean water taps located throughout the venue',
                  fullDetail: 'Organizers are legally bound to supply unlimited, clean, cold potable drinking water. '
                      'All ${festival.ecoCommitments.waterPointsCount} refill points are clearly marked on your on-site companion map with 💧 badges and require zero queuing fees.',
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF00E5FF),
                  sdgLabel: 'SDG 3: Good Health & Well-Being',
                ),
              ),
              const SizedBox(width: 8),
              _compactPerkChip(
                icon: Icons.medical_services_rounded,
                color: const Color(0xFFFF2E93),
                label: 'First Aid',
                onTap: () => _showCommitmentDetailModal(
                  title: 'Staffed First Aid & Sensory Chill Out',
                  subtitle: 'Safe, certified medical care and low-stimulation zones',
                  fullDetail: 'Includes ${festival.ecoCommitments.firstAidStationsCount} certified 24/7 Red Cross medical tents equipped with emergency defibrillators and certified doctors. '
                      'Also includes shaded sensory-friendly quiet rest zones with comfortable seating and mental health stewards.',
                  icon: Icons.medical_services_rounded,
                  color: const Color(0xFFFF2E93),
                  sdgLabel: 'SDG 3 & 16: Safe & Inclusive Festivals',
                ),
              ),
              const SizedBox(width: 8),
              _compactPerkChip(
                icon: Icons.local_drink_rounded,
                color: const Color(0xFF10B981),
                label: 'Reusable Cups',
                onTap: () => _showCommitmentDetailModal(
                  title: '100% Circular Hard-Cup System',
                  subtitle: 'Zero disposable cups or single-use plastic items',
                  fullDetail: 'Every visitor receives a durable, washable hard cup upon arrival. '
                      'Empty cups can be returned to any bar or return deposit machine for your token refund or a fresh, sanitized cup for your next drink, saving over 40,000 plastic cups per day.',
                  icon: Icons.local_drink_rounded,
                  color: const Color(0xFF10B981),
                  sdgLabel: 'SDG 12: Responsible Consumption',
                ),
              ),
              const SizedBox(width: 8),
              _compactPerkChip(
                icon: Icons.directions_bus_rounded,
                color: const Color(0xFFA855F7),
                label: 'Shuttle & Bikes',
                onTap: () => _showCommitmentDetailModal(
                  title: 'Zero-Emission Shuttles & Guarded Bike Hub',
                  subtitle: 'Sustainable transport from the nearest train station',
                  fullDetail: 'Electric shuttle buses run continuously between the local central train station and the festival gates every 10–15 minutes. '
                      'Guarded, illuminated bicycle parking with free tire pumps and charging stations for e-bikes is provided right by the main festival entrance.',
                  icon: Icons.directions_bus_rounded,
                  color: const Color(0xFFA855F7),
                  sdgLabel: 'SDG 11 & 13: Green Mobility & Climate Action',
                ),
              ),
              if (festival.ecoCommitments.recyclingStations) ...[
                const SizedBox(width: 8),
                _compactPerkChip(
                  icon: Icons.recycling_rounded,
                  color: const Color(0xFF3B82F6),
                  label: 'Recycling Hubs',
                  onTap: () => _showCommitmentDetailModal(
                    title: 'Waste Sorting & Circular Recycling',
                    subtitle: 'Clean festival grounds with 100% waste recovery',
                    fullDetail: 'Color-coded waste separation stations are located at every food court and stage exit, ensuring all plastic, organic waste, and cans are recycled.',
                    icon: Icons.recycling_rounded,
                    color: const Color(0xFF3B82F6),
                    sdgLabel: 'SDG 12: Responsible Consumption',
                  ),
                ),
              ],
              if (festival.ecoCommitments.renewableEnergy) ...[
                const SizedBox(width: 8),
                _compactPerkChip(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFFB300),
                  label: 'Solar & Green Power',
                  onTap: () => _showCommitmentDetailModal(
                    title: '100% Renewable Stage Power',
                    subtitle: 'Solar battery arrays & fixed green grid connection',
                    fullDetail: 'All stage sound systems and LED lighting rigs are powered entirely through renewable energy sources with zero diesel generator fumes.',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFFB300),
                    sdgLabel: 'SDG 7 & 13: Clean Energy',
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Attendance Counter Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Crowd Going via Festival Buddy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      '${festival.ticketsSoldInApp} / ${festival.capacity}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: soldRatio,
                  minHeight: 8,
                  color: const Color(0xFFFF2E93),
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Getting There & Transport Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to Get There & Shuttles',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _clickableAddressRow(
                  Icons.place_rounded,
                  'Venue',
                  festival.venueAddress,
                  festival.latitude,
                  festival.longitude,
                ),
                const Divider(height: 18),
                _infoRow(
                  Icons.train_rounded,
                  'Public Transport',
                  festival.publicTransportInfo,
                ),
                const Divider(height: 18),
                _infoRow(
                  Icons.directions_bus_filled_rounded,
                  'Festival Shuttle & Bikes',
                  festival.festivalTransportOffer,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open Interactive Venue Map & Lineup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCommitmentDetailModal({
    required String title,
    required String subtitle,
    required String fullDetail,
    required IconData icon,
    required Color color,
    required String sdgLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sdgLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                fullDetail,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Got it!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactPerkChip({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInExternalMaps(double lat, double lng, String address) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, color: Color(0xFFFF2E93)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Open in Maps',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              address,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_rounded, color: Colors.blue),
              ),
              title: const Text(
                'Open in Google Maps',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('https://maps.google.com/?q=$lat,$lng'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open Google Maps')),
                  );
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.apple_rounded, color: Colors.green),
              ),
              title: const Text(
                'Open in Apple Maps',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('maps://?q=$lat,$lng'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final appleUri = Uri.parse('maps://?q=$lat,$lng');
                final fallbackUri = Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=${Uri.encodeComponent(address)}');
                if (await canLaunchUrl(appleUri)) {
                  await launchUrl(appleUri, mode: LaunchMode.externalApplication);
                } else if (await canLaunchUrl(fallbackUri)) {
                  await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open Apple Maps')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _clickableAddressRow(
    IconData icon,
    String title,
    String body,
    double lat,
    double lng,
  ) {
    return InkWell(
      onTap: () => _openInExternalMaps(lat, lng, body),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFFFF2E93)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF6D28D9))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 11,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF6D28D9),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Open Maps',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF6D28D9),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.5,
                      decoration: TextDecoration.underline,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFFA855F7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTicketQrPainter extends CustomPainter {
  const _DetailTicketQrPainter({required this.seed});
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
  bool shouldRepaint(covariant _DetailTicketQrPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
