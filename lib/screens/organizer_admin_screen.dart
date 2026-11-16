import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/festival_models.dart';
import '../services/app_state.dart';
import '../services/sample_data.dart';

class OrganizerAdminScreen extends StatefulWidget {
  const OrganizerAdminScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<OrganizerAdminScreen> createState() => _OrganizerAdminScreenState();
}

class _OrganizerAdminScreenState extends State<OrganizerAdminScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _datesCtrl = TextEditingController(text: '06–07 September 2027');
  final _cityCtrl = TextEditingController(text: 'Breda, NL');
  final _venueCtrl = TextEditingController(text: 'Valkenberg Eco-Park, Breda');
  final _distanceCtrl = TextEditingController(text: '45');
  final _priceCtrl = TextEditingController(text: '65');
  final _howToGetThereCtrl = TextEditingController(
    text: '5-minute walk through Valkenberg Park directly from Breda Station.',
  );
  final _publicTransportCtrl = TextEditingController(
    text: 'NS Intercity direct every 15 mins + Arriva zero-emission city buses.',
  );
  final _festivalShuttleCtrl = TextEditingController(
    text: 'Free guarded bicycle parking & 15% NS green travel discount.',
  );

  String _selectedGenre = SampleData.allGenres.first;
  String? _uploadedBannerPath;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickBannerImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _uploadedBannerPath = image.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner image loaded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Organizer Mandatory & Optional SDG Commitments
  bool _pledgeWater = true;
  bool _pledgeFirstAidQuiet = true;
  bool _pledgeReusableCups = true;
  bool _pledgeRecycling = true;
  bool _pledgePublicTransit = true;
  final bool _pledgeBikeParking = true;
  bool _pledgeRenewableEnergy = true;
  final bool _pledgeSafeSpace = true;
  final bool _pledgeLocalPartners = true;
  bool _signedLegalResponsibilityAgreement = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _datesCtrl.dispose();
    _cityCtrl.dispose();
    _venueCtrl.dispose();
    _distanceCtrl.dispose();
    _priceCtrl.dispose();
    _howToGetThereCtrl.dispose();
    _publicTransportCtrl.dispose();
    _festivalShuttleCtrl.dispose();
    super.dispose();
  }

  void _submitNewFestival() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a festival name.')),
      );
      return;
    }
    if (!_pledgeWater ||
        !_pledgeFirstAidQuiet ||
        !_pledgeReusableCups ||
        !_pledgeRecycling ||
        !_signedLegalResponsibilityAgreement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Organizers must agree to core environmental & visitor safety commitments (free water, first aid, reusable cups, recycling) and sign the pledge.',
          ),
        ),
      );
      return;
    }

    final commitments = EcoCommitments(
      freeDrinkingWater: _pledgeWater,
      firstAidAndQuietZone: _pledgeFirstAidQuiet,
      publicTransportIncluded: _pledgePublicTransit,
      bicycleParking: _pledgeBikeParking,
      reusableCupsOnly: _pledgeReusableCups,
      recyclingStations: _pledgeRecycling,
      renewableEnergy: _pledgeRenewableEnergy,
      safeSpaceStewards: _pledgeSafeSpace,
      localEcoPartners: _pledgeLocalPartners,
    );

    widget.appState.createFestivalListing(
      name: _nameCtrl.text,
      tagline: _taglineCtrl.text.isEmpty
          ? 'Verified Sustainable Music & Arts Festival'
          : _taglineCtrl.text,
      dates: _datesCtrl.text,
      city: _cityCtrl.text,
      venueAddress: _venueCtrl.text,
      distanceKm: int.tryParse(_distanceCtrl.text) ?? 35,
      priceEur: double.tryParse(_priceCtrl.text) ?? 65.0,
      genres: [_selectedGenre, 'Indie & Alternative'],
      howToGetThere: _howToGetThereCtrl.text,
      publicTransportInfo: _publicTransportCtrl.text,
      festivalTransportOffer: _festivalShuttleCtrl.text,
      bannerImagePath: _uploadedBannerPath,
      ecoCommitments: commitments,
    );

    _nameCtrl.clear();
    _taglineCtrl.clear();
    setState(() {
      _uploadedBannerPath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.appState.activeRole == UserRole.admin
              ? 'Festival published and approved immediately!'
              : 'Festival submitted! Switch to Admin role below to approve it (<5 min SLA).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.appState.activeRole;
    final isAuthorized =
        role == UserRole.organizer || role == UserRole.admin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Role Switcher Banner for Easy Group Presentation Demo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Two-Sided Platform & RBAC (Current Role: ${role.name.toUpperCase()})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cybersecurity Requirement: Only Organizers and Administrators are authorized to create, edit, or remove festival listings. Use the role switcher below during your presentation:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.guest,
                      label: Text('Guest'),
                    ),
                    ButtonSegment(
                      value: UserRole.visitor,
                      label: Text('Visitor'),
                    ),
                    ButtonSegment(
                      value: UserRole.organizer,
                      label: Text('Organizer'),
                    ),
                    ButtonSegment(
                      value: UserRole.admin,
                      label: Text('Admin'),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (sel) =>
                      widget.appState.switchDemoRole(sel.first),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (!isAuthorized)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 48,
                    color: Color(0xFFD32F2F),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Restricted to Organizers & Administrators',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your current role is Guest/Visitor. To protect festival integrity and prevent unauthorized edits, only verified Organizers and Administrators can publish or manage festival listings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            widget.appState.switchDemoRole(UserRole.organizer),
                        icon: const Icon(Icons.festival_rounded),
                        label: const Text('Demo as Organizer'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            widget.appState.switchDemoRole(UserRole.admin),
                        icon: const Icon(Icons.security_rounded),
                        label: const Text('Demo as Admin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else ...[
          // ORGANIZER SECTION: SDG Responsibility Pledge + Add Festival
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.handshake_rounded, color: Color(0xFF1B5E20)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Organizer Portal: Publish Festival & SDG Responsibility Agreement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To list an event on Festival Buddy and sell tickets, organizers must commit to environmental stewardship and visitor well-being:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Festival Name *',
                      hintText: 'e.g., Eindhoven Solar Sound 2027',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _taglineCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Short Tagline',
                      hintText: 'Zero-waste outdoor weekend',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _datesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Event Dates',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedGenre,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Primary Music Genre',
                            border: OutlineInputBorder(),
                          ),
                          items: SampleData.allGenres
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedGenre = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ticket €',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _publicTransportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Public Transport Instructions (SDG 11)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Festival Banner Image Upload Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.image_rounded, color: Color(0xFF00E5FF), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Festival Banner Image',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickBannerImage,
                              icon: const Icon(Icons.file_upload_outlined, size: 16),
                              label: Text(_uploadedBannerPath != null ? 'Change Image' : 'Upload Banner'),
                            ),
                          ],
                        ),
                        if (_uploadedBannerPath != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                SizedBox(
                                  height: 120,
                                  width: double.infinity,
                                  child: kIsWeb
                                      ? Image.network(_uploadedBannerPath!, fit: BoxFit.cover)
                                      : Image.file(File(_uploadedBannerPath!), fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                      onPressed: () => setState(() => _uploadedBannerPath = null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mandatory Environmental & Visitor Safety Commitments:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgeWater,
                    onChanged: (v) => setState(() => _pledgeWater = v ?? false),
                    title: const Text(
                      'Provide free freshwater refill points (SDG 3 - Mandatory)',
                    ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgeFirstAidQuiet,
                    onChanged: (v) =>
                        setState(() => _pledgeFirstAidQuiet = v ?? false),
                    title: const Text(
                      'Provide staffed First Aid area & Quiet Rest Zone (SDG 3 - Mandatory)',
                    ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgeReusableCups,
                    onChanged: (v) =>
                        setState(() => _pledgeReusableCups = v ?? false),
                    title: const Text(
                      '100% hard reusable cups — no single-use plastic (SDG 12 - Mandatory)',
                    ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgeRecycling,
                    onChanged: (v) =>
                        setState(() => _pledgeRecycling = v ?? false),
                    title: const Text(
                      'Provide clearly marked recycling bins across grounds (SDG 12 - Mandatory)',
                    ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgePublicTransit,
                    onChanged: (v) =>
                        setState(() => _pledgePublicTransit = v ?? false),
                    title: const Text(
                      'Offer public transport integration / shuttle bus (SDG 11 & 13)',
                    ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pledgeRenewableEnergy,
                    onChanged: (v) =>
                        setState(() => _pledgeRenewableEnergy = v ?? false),
                    title: const Text(
                      'Use renewable solar/grid battery power (SDG 13)',
                    ),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _signedLegalResponsibilityAgreement,
                    onChanged: (v) => setState(
                      () => _signedLegalResponsibilityAgreement = v ?? false,
                    ),
                    title: const Text(
                      'I confirm on behalf of the organizer that all sustainability claims above are accurate and subject to visitor verification & Admin audit.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitNewFestival,
                      icon: const Icon(Icons.publish_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Sign SDG Agreement & Submit Festival'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ADMIN SECTION: Approve / Remove Listings & Review Anti-Greenwashing Reports
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin Governance: Listings & Misleading Claim Reports',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.appState.pendingFestivals.isNotEmpty) ...[
                    const Text(
                      'Pending Festival Approvals (<5 min visibility SLA):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...widget.appState.pendingFestivals.map(
                      (f) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          f.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${f.city} • Eco Score: ${f.ecoCommitments.ecoScorePercentage}%',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonal(
                              onPressed: () =>
                                  widget.appState.approveFestival(f.id),
                              child: const Text('Approve'),
                            ),
                            IconButton(
                              onPressed: () =>
                                  widget.appState.removeFestivalListing(f.id),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                  const Text(
                    'Visitor Reports (Anti-Greenwashing & Safety Verification):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  ...widget.appState.reports.map(
                    (rep) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${rep.festivalName} • ${rep.issueType}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  rep.status,
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rep.description,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    widget.appState.updateReportStatus(
                                  rep.id,
                                  'Verified & Organizer Warned',
                                ),
                                child: const Text(
                                  'Flag Organizer Claim',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    widget.appState.updateReportStatus(
                                  rep.id,
                                  'Resolved On-Site',
                                ),
                                child: const Text(
                                  'Mark Resolved',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
