import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/festival_models.dart';
import '../services/app_state.dart';
import '../services/sample_data.dart';

class ProfileSecurityScreen extends StatefulWidget {
  const ProfileSecurityScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  // 2-option toggle inside Profile: false = Visitor, true = Organizer
  bool _isOrganizerView = false;

  // Visitor Email OTP fields
  bool _showVisitorEmailOtpForm = false;
  final _visitorEmailInputCtrl =
      TextEditingController(text: 'maruf.visitor@fontys.nl');
  final _visitorOtpInputCtrl = TextEditingController();
  String? _visitorSentCode;
  String? _visitorAuthError;

  // Organizer Sign-in & KVK + Govt ID Verification fields
  String? _selectedOrganizerAuthMethod; // 'Google', 'Apple', 'Email (OTP)'
  bool _organizerEmailCodeVerified = false;
  final _orgAuthEmailCtrl = TextEditingController(text: 'contact@pulselive.nl');
  final _orgOtpCtrl = TextEditingController();
  String? _orgSentOtpCode;

  final _companyNameCtrl =
      TextEditingController(text: 'Pulse Live Events B.V.');
  final _kvkNumberCtrl = TextEditingController(text: '84920174');
  final _vatNumberCtrl = TextEditingController(text: 'NL863421098B01');
  final _orgPhoneCtrl = TextEditingController(text: '+31 40 851 9200');
  final _orgAddressCtrl = TextEditingController(
    text: 'Torenallee 20, Strijp-S, 5617 BC Eindhoven',
  );
  String _selectedGovIdType = 'Dutch / EU Passport';
  final _govIdNumberCtrl = TextEditingController(text: 'NW8492017');
  String? _uploadedGovIdFileName;
  String? _organizerFormError;

  @override
  void dispose() {
    _visitorEmailInputCtrl.dispose();
    _visitorOtpInputCtrl.dispose();
    _orgAuthEmailCtrl.dispose();
    _orgOtpCtrl.dispose();
    _companyNameCtrl.dispose();
    _kvkNumberCtrl.dispose();
    _vatNumberCtrl.dispose();
    _orgPhoneCtrl.dispose();
    _orgAddressCtrl.dispose();
    _govIdNumberCtrl.dispose();
    super.dispose();
  }

  void _openEditPersonalDetailsSheet() {
    final appState = widget.appState;
    final nameCtrl = TextEditingController(
      text: _isOrganizerView ? appState.organizerName : appState.visitorName,
    );
    final emailCtrl = TextEditingController(
      text: _isOrganizerView ? appState.organizerEmail : appState.visitorEmail,
    );
    final phoneCtrl = TextEditingController(
      text: _isOrganizerView ? appState.organizerPhone : appState.visitorPhone,
    );
    final addressCtrl = TextEditingController(
      text: _isOrganizerView
          ? appState.organizerAddress
          : appState.visitorAddress,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Personal Details',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name / Business Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E93),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  appState.updatePersonalDetails(
                    isOrganizer: _isOrganizerView,
                    name: nameCtrl.text,
                    email: emailCtrl.text,
                    phone: phoneCtrl.text,
                    address: addressCtrl.text,
                  );
                  Navigator.pop(ctx);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Requirement #2: Publish Event with All Details, Venue Cover Image & Terms & Conditions
  void _openPublishEventSheet() {
    final nameCtrl = TextEditingController();
    final taglineCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final datesCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final transportCtrl = TextEditingController();
    String selectedGenre = SampleData.allGenres.first;
    int? selectedCoverIndex = 0; // Default or custom
    String? customUploadedCoverPath;
    bool acceptedTermsAndConditions = false; // Must be checked!
    String? publishError;

    const coverOptions = [
      (
        label: 'Neon Laser Mainstage Cover',
        icon: Icons.wb_iridescent_rounded,
        c1: Color(0xFF7C3AED),
        c2: Color(0xFFFF2E93),
      ),
      (
        label: 'Sunset Waterfront Arena Cover',
        icon: Icons.wb_twilight_rounded,
        c1: Color(0xFFFF512F),
        c2: Color(0xFFDD2476),
      ),
      (
        label: 'Cyber Forest Stage Cover',
        icon: Icons.forest_rounded,
        c1: Color(0xFF00B4DB),
        c2: Color(0xFF6366F1),
      ),
      (
        label: 'Solar Meadow Dome Cover',
        icon: Icons.wb_sunny_rounded,
        c1: Color(0xFF10B981),
        c2: Color(0xFF3B82F6),
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFFFF2E93),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Publish a New Festival Event',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'All event details, a Venue Cover Image, and Terms & Conditions acceptance are required.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                if (publishError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(
                      publishError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),

                // 1. Mandatory Upload / Select Venue Cover Image
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '1. Upload Cover Image *',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery);
                        if (img != null) {
                          setModalState(() {
                            customUploadedCoverPath = img.path;
                            selectedCoverIndex = -1;
                          });
                        }
                      },
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      label: Text(customUploadedCoverPath != null ? 'Change Photo' : 'Upload From Device'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (customUploadedCoverPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: kIsWeb
                              ? Image.network(customUploadedCoverPath!, fit: BoxFit.cover)
                              : Image.file(File(customUploadedCoverPath!), fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              onPressed: () => setModalState(() {
                                customUploadedCoverPath = null;
                                selectedCoverIndex = 0;
                              }),
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 8,
                          left: 8,
                          child: Chip(
                            backgroundColor: Colors.black87,
                            avatar: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            label: Text('Custom Cover Loaded', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'Or pick a venue style template:',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: coverOptions.length,
                  itemBuilder: (context, idx) {
                    final opt = coverOptions[idx];
                    final isSel = selectedCoverIndex == idx;
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        selectedCoverIndex = idx;
                        customUploadedCoverPath = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [opt.c1, opt.c2]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: isSel ? 3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(opt.icon, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opt.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSel)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),
                const Text(
                  '2. Event Details *',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Festival Name *',
                    hintText: 'e.g., Eindhoven Neon Pulse',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taglineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short Tagline *',
                    hintText: 'e.g., 3 Days of Electronic & Light Art',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          hintText: 'Eindhoven',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: datesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Event Dates *',
                          hintText: '06–07 Sep',
                          border: OutlineInputBorder(),
                          isDense: true,
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
                        initialValue: selectedGenre,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Music Genre *',
                          border: OutlineInputBorder(),
                          isDense: true,
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
                          if (v != null) setModalState(() => selectedGenre = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 105,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (€) *',
                          hintText: '65',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: venueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Exact Venue Address *',
                    hintText: 'Strijp-S Grounds, Eindhoven',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: transportCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Shuttle & Public Transport Info *',
                    hintText: 'Free shuttle from Central Station every 10m',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Mandatory Terms & Conditions Checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptedTermsAndConditions,
                  onChanged: (v) => setModalState(
                    () => acceptedTermsAndConditions = v ?? false,
                  ),
                  title: const Text(
                    'I agree to the Festival Buddy Organizer Terms & Conditions (providing free drinking water, first aid, and verified event details). *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E93),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (selectedCoverIndex == null) {
                        setModalState(() {
                          publishError =
                              'Please select a Venue Cover Image above.';
                        });
                        return;
                      }
                      if (nameCtrl.text.trim().isEmpty ||
                          taglineCtrl.text.trim().isEmpty ||
                          cityCtrl.text.trim().isEmpty ||
                          datesCtrl.text.trim().isEmpty ||
                          venueCtrl.text.trim().isEmpty ||
                          priceCtrl.text.trim().isEmpty ||
                          transportCtrl.text.trim().isEmpty) {
                        setModalState(() {
                          publishError =
                              'Please fill in all required event details (*).';
                        });
                        return;
                      }
                      if (!acceptedTermsAndConditions) {
                        setModalState(() {
                          publishError =
                              'You must check and accept the Terms & Conditions to publish.';
                        });
                        return;
                      }

                      final chosenCover = selectedCoverIndex != null && selectedCoverIndex! >= 0
                          ? coverOptions[selectedCoverIndex!]
                          : coverOptions.first;
                      widget.appState.createFestivalListing(
                        name: nameCtrl.text,
                        tagline: taglineCtrl.text,
                        dates: datesCtrl.text,
                        city: cityCtrl.text,
                        venueAddress: venueCtrl.text,
                        distanceKm: 8,
                        priceEur: double.tryParse(priceCtrl.text) ?? 65.0,
                        genres: [selectedGenre],
                        howToGetThere: transportCtrl.text,
                        publicTransportInfo: transportCtrl.text,
                        festivalTransportOffer:
                            'Free shuttle bus & guarded bike parking included.',
                        coverImageLabel: customUploadedCoverPath != null ? 'Uploaded Custom Banner' : chosenCover.label,
                        coverIcon: chosenCover.icon,
                        bannerImagePath: customUploadedCoverPath,
                        primaryColor: chosenCover.c1,
                        secondaryColor: chosenCover.c2,
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
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Event submitted for review! Awaiting admin approval before publishing to Discover.',
                          ),
                          backgroundColor: Color(0xFF7C3AED),
                        ),
                      );
                    },
                    icon: const Icon(Icons.publish_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        'Publish Event',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // 2-Option Toggle: Visitor | Organizer
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isOrganizerView = false);
                    appState.setProfileViewingOrganizer(false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: !_isOrganizerView
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: !_isOrganizerView ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Visitor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                !_isOrganizerView ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isOrganizerView = true);
                    appState.setProfileViewingOrganizer(true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: _isOrganizerView
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.stadium_rounded,
                          size: 18,
                          color: _isOrganizerView ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Organizer',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                _isOrganizerView ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        if (!_isOrganizerView)
          _buildVisitorSection(context, appState)
        else
          _buildOrganizerSection(context, appState),
      ],
    );
  }

  // ============================================================================
  // VISITOR SECTION: 3 SIGN-IN OPTIONS (GOOGLE / APPLE / EMAIL OTP) -> PROFILE
  // ============================================================================
  Widget _buildVisitorSection(BuildContext context, AppState appState) {
    if (!appState.isVisitorAuthenticated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.login_rounded, color: Color(0xFFFF2E93)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visitor Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Currently browsing as Guest. Sign in with Google, Apple, or Email Verification Code:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_visitorAuthError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _visitorAuthError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Option 1: Google Sign-In
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () {
                    appState.completeVisitorSignIn(
                      method: 'Google',
                      email: 'maruf.google@gmail.com',
                      name: 'Maruf Ahmed',
                    );
                  },
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: Apple Sign-In
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () {
                    appState.completeVisitorSignIn(
                      method: 'Apple ID',
                      email: 'maruf.apple@icloud.com',
                      name: 'Maruf Ahmed',
                    );
                  },
                  icon: const Icon(Icons.apple_rounded, size: 22),
                  label: const Text(
                    'Continue with Apple',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 3: Email with Verification Code
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => setState(
                    () => _showVisitorEmailOtpForm = !_showVisitorEmailOtpForm,
                  ),
                  icon: const Icon(Icons.mark_email_read_rounded, size: 20),
                  label: const Text(
                    'Continue with Email (Verification Code)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_showVisitorEmailOtpForm) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _visitorEmailInputCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final code = appState.sendEmailVerificationCode(
                          _visitorEmailInputCtrl.text,
                        );
                        setState(() {
                          _visitorSentCode = code;
                          _visitorOtpInputCtrl.text = code;
                          _visitorAuthError = null;
                        });
                      },
                      child: const Text('Send Code'),
                    ),
                  ],
                ),
                if (_visitorSentCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Verification code sent to email: $_visitorSentCode',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _visitorOtpInputCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Enter 6-Digit Verification Code',
                    prefixIcon: Icon(Icons.pin_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E93),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (!appState
                          .verifyEmailOtpCode(_visitorOtpInputCtrl.text)) {
                        setState(() {
                          _visitorAuthError =
                              'Invalid verification code. Tap "Send Code" first.';
                        });
                        return;
                      }
                      appState.completeVisitorSignIn(
                        method: 'Email (Code Verified)',
                        email: _visitorEmailInputCtrl.text,
                      );
                    },
                    child: const Text('Verify Code & Sign In'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Authenticated Visitor Profile View
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileBanner(
          title: appState.visitorName,
          subtitle:
              '${appState.visitorEmail} • Signed in via ${appState.visitorAuthMethod}',
          badge: 'VERIFIED VISITOR',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Personal Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            TextButton.icon(
              onPressed: _openEditPersonalDetailsSheet,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
        Card(
          child: Column(
            children: [
              _buildDetailTile(
                icon: Icons.alternate_email_rounded,
                label: 'Unique Community Username',
                value: appState.visitorUsername,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.badge_outlined,
                label: 'Full Name',
                value: appState.visitorName,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: appState.visitorEmail,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: appState.visitorPhone,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: appState.visitorAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: appState.signOutToGuest,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out to Guest View'),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // ORGANIZER SECTION: GOOGLE/APPLE/EMAIL OTP + KVK & GOVT ID VERIFICATION
  // ============================================================================
  Widget _buildOrganizerSection(BuildContext context, AppState appState) {
    if (!appState.isOrganizerAuthenticated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF00E5FF)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Organizer Verification & Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'To prevent fraud and fake organizers, event hosts must authenticate and verify their KVK business registration and Official Government ID.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),

              if (_organizerFormError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _organizerFormError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),

              // Step 1: 3 Sign-In Options (Google, Apple, Email with Verification Code)
              const Text(
                'Step 1: Choose Sign-In Method *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.g_mobiledata_rounded, size: 20),
                    label: const Text('Google'),
                    selected: _selectedOrganizerAuthMethod == 'Google',
                    onSelected: (_) => setState(() {
                      _selectedOrganizerAuthMethod = 'Google';
                      _organizerEmailCodeVerified = true;
                    }),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.apple_rounded, size: 18),
                    label: const Text('Apple'),
                    selected: _selectedOrganizerAuthMethod == 'Apple',
                    onSelected: (_) => setState(() {
                      _selectedOrganizerAuthMethod = 'Apple';
                      _organizerEmailCodeVerified = true;
                    }),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.mark_email_read_rounded, size: 16),
                    label: const Text('Email + Code'),
                    selected: _selectedOrganizerAuthMethod == 'Email (OTP)',
                    onSelected: (_) => setState(() {
                      _selectedOrganizerAuthMethod = 'Email (OTP)';
                      _organizerEmailCodeVerified = false;
                    }),
                  ),
                ],
              ),

              if (_selectedOrganizerAuthMethod == 'Email (OTP)') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orgAuthEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Business Email',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () {
                        final code = appState.sendEmailVerificationCode(
                          _orgAuthEmailCtrl.text,
                        );
                        setState(() {
                          _orgSentOtpCode = code;
                          _orgOtpCtrl.text = code;
                        });
                      },
                      child: const Text('Send Code'),
                    ),
                  ],
                ),
                if (_orgSentOtpCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Verification code sent: $_orgSentOtpCode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orgOtpCtrl,
                        decoration: const InputDecoration(
                          labelText: '6-Digit Verification Code',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (appState.verifyEmailOtpCode(_orgOtpCtrl.text)) {
                          setState(() => _organizerEmailCodeVerified = true);
                        }
                      },
                      child: Text(
                        _organizerEmailCodeVerified ? 'Verified ✓' : 'Verify',
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 24),

              // Step 2: Business & KVK Details
              const Text(
                'Step 2: Business & KVK Registration Details *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _companyNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Registered Business / Company Name *',
                  prefixIcon: Icon(Icons.business_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kvkNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'KVK Number (8 digits) *',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _vatNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'VAT / BTW Number *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Phone Number *',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Registered Business Address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              const Divider(height: 24),

              // Step 3: Official Govt. ID Verification
              const Text(
                'Step 3: Official Government ID Verification (Anti-Fraud) *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedGovIdType,
                decoration: const InputDecoration(
                  labelText: 'Official Government ID Type *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Dutch / EU Passport',
                    child: Text('Dutch / EU Passport'),
                  ),
                  DropdownMenuItem(
                    value: 'National Identity Card (ID)',
                    child: Text('National Identity Card (ID)'),
                  ),
                  DropdownMenuItem(
                    value: 'Official Driver License',
                    child: Text('Official Driver License'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedGovIdType = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _govIdNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document / Passport Number *',
                  prefixIcon: Icon(Icons.badge_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(
                    color: _uploadedGovIdFileName != null
                        ? const Color(0xFF10B981)
                        : const Color(0xFFA855F7),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _uploadedGovIdFileName =
                        'Official_Govt_ID_${_govIdNumberCtrl.text}_Scan.pdf';
                  });
                },
                icon: Icon(
                  _uploadedGovIdFileName != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: _uploadedGovIdFileName != null
                      ? const Color(0xFF10B981)
                      : null,
                ),
                label: Text(
                  _uploadedGovIdFileName != null
                      ? 'Uploaded: $_uploadedGovIdFileName'
                      : 'Upload Official Govt. ID Scan *',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2E93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (_selectedOrganizerAuthMethod == null) {
                      setState(() {
                        _organizerFormError =
                            'Please select Google, Apple, or Email sign-in in Step 1.';
                      });
                      return;
                    }
                    if (_selectedOrganizerAuthMethod == 'Email (OTP)' &&
                        !_organizerEmailCodeVerified) {
                      setState(() {
                        _organizerFormError =
                            'Please send and verify your 6-digit email code in Step 1.';
                      });
                      return;
                    }
                    if (_companyNameCtrl.text.trim().isEmpty ||
                        _kvkNumberCtrl.text.trim().length < 6 ||
                        _vatNumberCtrl.text.trim().isEmpty ||
                        _orgPhoneCtrl.text.trim().isEmpty ||
                        _orgAddressCtrl.text.trim().isEmpty ||
                        _govIdNumberCtrl.text.trim().isEmpty) {
                      setState(() {
                        _organizerFormError =
                            'Please complete all Business, KVK, and Govt. ID fields.';
                      });
                      return;
                    }
                    if (_uploadedGovIdFileName == null) {
                      setState(() {
                        _organizerFormError =
                            'Please upload your Official Government ID scan in Step 3.';
                      });
                      return;
                    }

                    appState.completeOrganizerRegistration(
                      authMethod: _selectedOrganizerAuthMethod!,
                      companyName: _companyNameCtrl.text,
                      email: _orgAuthEmailCtrl.text,
                      phone: _orgPhoneCtrl.text,
                      businessAddress: _orgAddressCtrl.text,
                      kvkNumber: _kvkNumberCtrl.text,
                      vatNumber: _vatNumberCtrl.text,
                      govIdType: _selectedGovIdType,
                      govIdDocumentNumber: _govIdNumberCtrl.text,
                      govIdFileName: _uploadedGovIdFileName!,
                    );
                  },
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text(
                    'Verify Identity & Activate Organizer Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Verified Organizer Profile & Publish Event View
    final kvk = appState.organizerKvkVerification;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileBanner(
          title: appState.organizerName,
          subtitle:
              'KVK: ${kvk?.kvkNumber ?? "84920174"} • Govt. ID Verified ✓',
          badge: 'KVK & GOVT ID VERIFIED ORGANIZER',
          icon: Icons.stadium_rounded,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF2E93),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _openPublishEventSheet,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text(
              'Publish a New Festival Event',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // AI Ingestion Review Queue
        _buildAiIngestionReviewSection(context, appState),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verified Business & Identity Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            TextButton.icon(
              onPressed: _openEditPersonalDetailsSheet,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
        Card(
          child: Column(
            children: [
              _buildDetailTile(
                icon: Icons.business_rounded,
                label: 'Business Name',
                value: appState.organizerName,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.numbers_rounded,
                label: 'KVK & VAT Number',
                value:
                    'KVK: ${kvk?.kvkNumber ?? "84920174"} • VAT: ${kvk?.vatNumber ?? "NL863421098B01"}',
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.verified_user_outlined,
                label: 'Official Govt. ID Verification',
                value:
                    '${kvk?.govIdType ?? "Passport"} (${kvk?.govIdDocumentNumber ?? "NW8492017"}) • Verified',
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.email_outlined,
                label: 'Business Email',
                value: appState.organizerEmail,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: appState.organizerPhone,
              ),
              const Divider(height: 1, indent: 56),
              _buildDetailTile(
                icon: Icons.location_on_outlined,
                label: 'Business Address',
                value: appState.organizerAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: appState.signOutToGuest,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out to Guest View'),
          ),
        ),
      ],
    );
  }

  Widget _buildAiIngestionReviewSection(
      BuildContext context, AppState appState) {
    final aiPending =
        appState.allFestivals.where((f) => f.isAiIngested && !f.isApprovedByAdmin).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'AI Event Radar Review Queue (${aiPending.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Automated AI crawler searches 5 Dutch events per 24h & verifies KVK, TLS, and Social Media Badges. Click the source link to inspect in your browser before approving.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        if (aiPending.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All crawled events reviewed! The AI Radar background crawler will stage newly discovered events here.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...aiPending.map(
            (fest) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(fest.coverIcon,
                              color: const Color(0xFF00E5FF), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fest.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${fest.city} • ${fest.dates}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Score: ${(fest.aiVerificationScore * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () async {
                              final rawUrl = fest.aiSourceUrl ?? 'https://solarweekend.com/nl';
                              final uri = Uri.tryParse(rawUrl);
                              if (uri != null) {
                                try {
                                  final launched = await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (!launched && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open $rawUrl in browser.')),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Opening $rawUrl in browser...')),
                                    );
                                  }
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.open_in_browser_rounded,
                                      size: 16, color: Color(0xFF00E5FF)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      fest.aiSourceUrl ?? 'https://official-source.nl',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF00E5FF),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Open Link ↗',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fest.aiVerificationReport ?? 'KVK and official domain verified.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (fest.socialMediaVerification != null) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            const Text(
                              'Social Media Verified Badge Status:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: fest.socialMediaVerification!.entries.map((entry) {
                                final channel = entry.key[0].toUpperCase() + entry.key.substring(1);
                                final isVerified = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isVerified
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isVerified
                                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVerified
                                            ? Icons.verified_rounded
                                            : Icons.cancel_outlined,
                                        size: 13,
                                        color: isVerified
                                            ? const Color(0xFF10B981)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$channel: ${isVerified ? "Verified Badge ✓" : "Unverified"}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isVerified
                                              ? const Color(0xFF10B981)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            onPressed: () {
                              appState.removeFestivalListing(fest.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rejected and removed "${fest.name}".'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject / Flag'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              appState.approveFestival(fest.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Approved "${fest.name}"! Published to Discover.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Approve & Publish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileBanner({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFFF2E93)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFFA855F7), size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
