import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../models/festival_models.dart';
import '../services/app_state.dart';

const String kCustomFestivalMapboxStyleUri =
    'mapbox://styles/marufatfontys/cmwbaxrda008e01s82twlb0i7';

Future<Uint8List> _generatePinMarkerPng({
  required String symbol,
  required Color color,
  bool isStage = false,
  bool isFriend = false,
}) async {
  // Woov-style 3D floating badge marker
  final recorder = ui.PictureRecorder();
  // 108x120 canvas to include drop shadow, 3D pill badge, and ground pointer
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 108, 120));

  // 1. Ground contact shadow (isometric oval)
  final groundShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.45)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(54, 110), width: 36, height: 14),
    groundShadowPaint,
  );

  // 2. Glow aura behind the badge (neon glow)
  final glowPaint = Paint()
    ..color = color.withValues(alpha: 0.50)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  canvas.drawCircle(const Offset(54, 48), 38, glowPaint);

  // 3. Pointer pin tip pointing to ground
  final pointerPath = Path()
    ..moveTo(54, 104)
    ..lineTo(40, 68)
    ..lineTo(68, 68)
    ..close();
  final pointerPaint = Paint()..color = color;
  canvas.drawPath(pointerPath, pointerPaint);

  final pointerBorderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  canvas.drawPath(pointerPath, pointerBorderPaint);

  // 4. Main 3D Floating Circle Badge
  final mainCirclePaint = Paint()..color = color;
  canvas.drawCircle(const Offset(54, 48), 36, mainCirclePaint);

  // 5. White glossy border
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  canvas.drawCircle(const Offset(54, 48), 36, borderPaint);

  // 6. Stage crown or special ring indicator
  if (isStage) {
    final stageRingPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(54, 48), 30, stageRingPaint);
  }

  // 7. Inner Symbol / Emoji
  final textPainter = TextPainter(
    text: TextSpan(
      text: symbol,
      style: TextStyle(
        fontSize: isFriend ? 24 : 26,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    Offset(54 - textPainter.width / 2, 48 - textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(108, 120);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

String _categorySymbol(MapPinCategory cat) {
  switch (cat) {
    case MapPinCategory.water:
      return '💧';
    case MapPinCategory.firstAid:
      return '🏥';
    case MapPinCategory.stage:
      return '🎵';
    case MapPinCategory.quietZone:
      return '🧘';
    case MapPinCategory.toilet:
      return '🚻';
    case MapPinCategory.recycling:
      return '♻️';
    case MapPinCategory.bikeParking:
      return '🚲';
  }
}

class CompanionView extends StatefulWidget {
  const CompanionView({
    super.key,
    required this.appState,
    required this.festival,
    this.showFestivalSelector = false,
  });

  final AppState appState;
  final Festival festival;
  final bool showFestivalSelector;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView> {
  mbx.MapboxMap? _mapboxMap;
  mbx.MapboxMap? get activeMapboxMap => _mapboxMap;

  MapPinPoint? _selectedMapPin;
  PersonalSavedPin? _selectedPersonalPin;
  BuddyFriend? _selectedFriendPin;
  StreamSubscription<Position>? _positionSub;
  Position? _currentLiveGpsPosition;
  mbx.PointAnnotationManager? _pointManager;
  mbx.PointAnnotation? _userGpsAnnotation;
  mbx.CircleAnnotationManager? _circleManager;
  mbx.CircleAnnotation? _userCircleHalo;
  mbx.CircleAnnotation? _userCircleCore;

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _listenToLiveLocation() async {
    _positionSub?.cancel();
    if (!widget.appState.isDeviceLocationEnabled) return;

    // Check & request location permission immediately if needed
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
    } catch (_) {}

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() => _currentLiveGpsPosition = pos);
        _updateUserLiveMarker(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _currentLiveGpsPosition = pos;
        });
        _updateUserLiveMarker(pos.latitude, pos.longitude);
      }
    });
  }

  void _updateUserLiveMarker(double lat, double lng) async {
    // 1. High visibility glowing circle puck
    if (_circleManager != null) {
      try {
        final pt = mbx.Point(coordinates: mbx.Position(lng, lat));
        if (_userCircleHalo != null && _userCircleCore != null) {
          _userCircleHalo!.geometry = pt;
          _userCircleCore!.geometry = pt;
          await _circleManager!.update(_userCircleHalo!);
          await _circleManager!.update(_userCircleCore!);
        } else {
          _userCircleHalo = await _circleManager!.create(
            mbx.CircleAnnotationOptions(
              geometry: pt,
              circleRadius: 18.0,
              circleColor: const Color(0x5500E5FF).toARGB32(),
              circleStrokeWidth: 2.0,
              circleStrokeColor: const Color(0xFF00E5FF).toARGB32(),
            ),
          );
          _userCircleCore = await _circleManager!.create(
            mbx.CircleAnnotationOptions(
              geometry: pt,
              circleRadius: 7.5,
              circleColor: const Color(0xFF00E5FF).toARGB32(),
              circleStrokeWidth: 2.5,
              circleStrokeColor: Colors.white.toARGB32(),
            ),
          );
        }
      } catch (_) {}
    }

    // 2. High visibility pin badge
    if (_pointManager != null) {
      try {
        final pt = mbx.Point(coordinates: mbx.Position(lng, lat));
        if (_userGpsAnnotation != null) {
          _userGpsAnnotation!.geometry = pt;
          await _pointManager!.update(_userGpsAnnotation!);
        } else {
          final gpsBytes = await _generatePinMarkerPng(
            symbol: '📍',
            color: const Color(0xFF00E5FF),
          );
          _userGpsAnnotation = await _pointManager!.create(
            mbx.PointAnnotationOptions(
              geometry: pt,
              image: gpsBytes,
              iconSize: 0.75,
              textField: 'You',
              textColor: const Color(0xFF00E5FF).toARGB32(),
              textSize: 12.0,
              textOffset: [0.0, 1.8],
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _onMapboxCreated(mbx.MapboxMap mapbox) async {
    _mapboxMap = mapbox;
    final lat = widget.festival.latitude;
    final lng = widget.festival.longitude;

    // Immediately focus on festival venue coordinates
    mapbox.setCamera(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(lng, lat)),
        zoom: 16.5,
        pitch: 58.0,
        bearing: -25.0,
      ),
    );

    // Enable native real-time GPS location puck on Mapbox
    if (widget.appState.isDeviceLocationEnabled) {
      try {
        await mapbox.location.updateSettings(
          mbx.LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            pulsingColor: const Color(0xFF00E5FF).toARGB32(),
            showAccuracyRing: true,
            accuracyRingColor: const Color(0x3300E5FF).toARGB32(),
            puckBearingEnabled: true,
          ),
        );
      } catch (_) {}
    }

    try {
      _circleManager = await mapbox.annotations.createCircleAnnotationManager();

      // 1. Highlight the whole Festival Area Perimeter with glowing purple polygon
      final polyManager = await mapbox.annotations.createPolygonAnnotationManager();
      const deltaLat = 0.0035;
      const deltaLng = 0.0055;
      polyManager.create(
        mbx.PolygonAnnotationOptions(
          geometry: mbx.Polygon(coordinates: [
            [
              mbx.Position(lng - deltaLng, lat - deltaLat),
              mbx.Position(lng + deltaLng, lat - deltaLat * 0.8),
              mbx.Position(lng + deltaLng * 0.9, lat + deltaLat),
              mbx.Position(lng - deltaLng * 0.8, lat + deltaLat * 1.1),
              mbx.Position(lng - deltaLng, lat - deltaLat),
            ]
          ]),
          fillColor: const Color(0xFF7C3AED).withValues(alpha: 0.28).toARGB32(),
          fillOutlineColor: const Color(0xFFFF2E93).toARGB32(),
        ),
      );

      // 2. Add visual icons with symbols for every venue spot (water, toilets, stages, medical)
      _pointManager = await mapbox.annotations.createPointAnnotationManager();
      for (final pin in widget.festival.mapPins) {
        final pLat = lat + (pin.y - 0.5) * 0.005;
        final pLng = lng + (pin.x - 0.5) * 0.007;
        final symbol = _categorySymbol(pin.category);
        final iconBytes = await _generatePinMarkerPng(
          symbol: symbol,
          color: pin.category.color,
        );

        _pointManager!.create(
          mbx.PointAnnotationOptions(
            geometry: mbx.Point(coordinates: mbx.Position(pLng, pLat)),
            image: iconBytes,
            iconSize: 0.65,
            textField: pin.title,
            textColor: Colors.white.toARGB32(),
            textSize: 11.5,
            textOffset: [0.0, 1.8],
          ),
        );
      }

      // 3. Add Personal Pins (Car, Tent) with icon badges
      final myPins = widget.appState.getPersonalPins(widget.festival.id);
      for (final pPin in myPins) {
        final pLat = lat + (pPin.y - 0.5) * 0.005;
        final pLng = lng + (pPin.x - 0.5) * 0.007;
        final symbol = pPin.type == PersonalPinType.car
            ? '🚗'
            : pPin.type == PersonalPinType.bike
                ? '🚲'
                : '⛺';
        final iconBytes = await _generatePinMarkerPng(
          symbol: symbol,
          color: pPin.type.color,
        );
        _pointManager!.create(
          mbx.PointAnnotationOptions(
            geometry: mbx.Point(coordinates: mbx.Position(pLng, pLat)),
            image: iconBytes,
            iconSize: 0.65,
            textField: pPin.zoneLabel,
            textColor: const Color(0xFF00E5FF).toARGB32(),
            textSize: 11.0,
            textOffset: [0.0, 1.8],
          ),
        );
      }

      // 4. Add Friend Pins & User GPS marker if location enabled
      if (widget.appState.isDeviceLocationEnabled) {
        for (final friend in widget.appState.myFriends) {
          if (friend.sharedLocation != null) {
            final fLat = lat + (friend.venueY - 0.5) * 0.005;
            final fLng = lng + (friend.venueX - 0.5) * 0.007;
            final iconBytes = await _generatePinMarkerPng(
              symbol: friend.name.characters.first,
              color: friend.avatarColor,
            );
            _pointManager!.create(
              mbx.PointAnnotationOptions(
                geometry: mbx.Point(coordinates: mbx.Position(fLng, fLat)),
                image: iconBytes,
                iconSize: 0.65,
                textField: friend.name,
                textColor: Colors.white.toARGB32(),
                textSize: 11.0,
                textOffset: [0.0, 1.8],
              ),
            );
          }
        }
      }
    } catch (_) {}

    _listenToLiveLocation();
  }

  void _openFullScreenMapModal(BuildContext context, Festival fest) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullScreenMapScreen(
          appState: widget.appState,
          festival: fest,
        ),
      ),
    );
  }
  void _unpinLocation(PersonalPinType type) {
    widget.appState.removePersonalPin(
      festivalId: widget.festival.id,
      type: type,
    );
    if (_selectedPersonalPin?.type == type) {
      setState(() => _selectedPersonalPin = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${type.label} unpinned from map.')),
    );
  }

  // Requirement #6: Auto-detect location & pin spot (requires device location enabled)
  void _triggerAutoDetectPin(PersonalPinType type, PersonalSavedPin? existing) async {
    if (!widget.appState.isDeviceLocationEnabled) {
      _showEnableLocationDialog(type);
      return;
    }

    final autoPin = await widget.appState.autoDetectAndPinSpot(
      festival: widget.festival,
      type: type,
    );

    if (autoPin != null) {
      setState(() {
        _selectedPersonalPin = autoPin;
        _selectedMapPin = null;
        _selectedFriendPin = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 GPS Auto-Detected: ${autoPin.zoneLabel} pinned!',
            ),
          ),
        );
      }
    }
  }

  void _toggleGpsWithPermission(bool enable) async {
    if (enable) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied. Please enable in Settings.'),
            ),
          );
        }
        return;
      }
      widget.appState.setDeviceLocationEnabled(true);
      _mapboxMap?.location.updateSettings(
        mbx.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: const Color(0xFF00E5FF).toARGB32(),
          showAccuracyRing: true,
          accuracyRingColor: const Color(0x3300E5FF).toARGB32(),
          puckBearingEnabled: true,
        ),
      );
      _listenToLiveLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Live GPS Tracking & Auto-Pinning active!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } else {
      widget.appState.setDeviceLocationEnabled(false);
      _mapboxMap?.location.updateSettings(
        mbx.LocationComponentSettings(enabled: false),
      );
      _positionSub?.cancel();
    }
  }

  void _showEnableLocationDialog(PersonalPinType type) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_disabled_rounded, color: Color(0xFFFF2E93)),
            SizedBox(width: 8),
            Expanded(child: Text('Device Location Required')),
          ],
        ),
        content: Text(
          'To auto-detect and pin your ${type.label} (or see where friends are), please enable location services on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF2E93),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.appState.setDeviceLocationEnabled(true);
              Navigator.pop(ctx);
              _triggerAutoDetectPin(type, null);
            },
            icon: const Icon(Icons.gps_fixed_rounded),
            label: const Text('Enable Location & Auto-Pin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fest = widget.festival;
    final personalPins = widget.appState.getPersonalPins(fest.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Event Location Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2E93).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFF2E93),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fest.venueAddress,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fest.city} • ${fest.distanceKm} km away • ${fest.latitude.toStringAsFixed(4)}° N, ${fest.longitude.toStringAsFixed(4)}° E',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Device Location Status Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  widget.appState.isDeviceLocationEnabled
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_off_rounded,
                  size: 16,
                  color: widget.appState.isDeviceLocationEnabled
                      ? const Color(0xFF10B981)
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.appState.isDeviceLocationEnabled
                      ? (_currentLiveGpsPosition != null
                          ? 'GPS Live: ${_currentLiveGpsPosition!.latitude.toStringAsFixed(4)}°, ${_currentLiveGpsPosition!.longitude.toStringAsFixed(4)}°'
                          : 'Live iPhone GPS Active')
                      : 'GPS Disabled (Enable for Live Location)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: widget.appState.isDeviceLocationEnabled
                        ? const Color(0xFF10B981)
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            Switch(
              value: widget.appState.isDeviceLocationEnabled,
              onChanged: (v) => _toggleGpsWithPermission(v),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Pure Interactive Vector Mapbox Canvas (Tapping opens Fullscreen)
        GestureDetector(
          onTap: () => _openFullScreenMapModal(context, fest),
          child: Container(
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: mbx.MapWidget(
                    key: ValueKey('companion_mapbox_${widget.festival.id}'),
                    styleUri: kCustomFestivalMapboxStyleUri,
                    viewport: mbx.CameraViewportState(
                      center: mbx.Point(coordinates: mbx.Position(widget.festival.longitude, widget.festival.latitude)),
                      zoom: 16.5,
                      pitch: 58.0,
                      bearing: -25.0,
                    ),
                    onMapCreated: _onMapboxCreated,
                  ),
                ),

                // Floating Header & Tap to Expand Indicator
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.view_in_ar_rounded, color: Color(0xFF00E5FF), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              '${widget.festival.name} 3D Grounds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full_rounded, color: Color(0xFF00E5FF), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Tap to open full screen',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Center on My Location Button
                if (widget.appState.isDeviceLocationEnabled)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_gps_mini_${widget.festival.id}',
                      backgroundColor: const Color(0xFF131124),
                      foregroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      onPressed: () {
                        if (_currentLiveGpsPosition != null) {
                          _mapboxMap?.flyTo(
                            mbx.CameraOptions(
                              center: mbx.Point(
                                coordinates: mbx.Position(
                                  _currentLiveGpsPosition!.longitude,
                                  _currentLiveGpsPosition!.latitude,
                                ),
                              ),
                              zoom: 17.5,
                              pitch: 45.0,
                              bearing: 0.0,
                            ),
                            mbx.MapAnimationOptions(duration: 1000),
                          );
                        } else {
                          _listenToLiveLocation();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Acquiring live GPS fix...')),
                          );
                        }
                      },
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ),

                // Transparent Tap Interceptor so tapping anywhere expands to full screen (ignoring FAB area)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.82,
                      heightFactor: 0.85,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openFullScreenMapModal(context, fest),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected Pin Detail Popup
        if (_selectedMapPin != null) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _selectedMapPin!.category.color,
                child: Icon(
                  _selectedMapPin!.category.icon,
                  color: Colors.white,
                ),
              ),
              title: Text(
                _selectedMapPin!.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_selectedMapPin!.subtitle} • ${_selectedMapPin!.statusBadge}',
              ),
            ),
          ),
        ],

        if (_selectedFriendPin != null) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _selectedFriendPin!.avatarColor,
                child: Text(
                  _selectedFriendPin!.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Friend: ${_selectedFriendPin!.name} (${_selectedFriendPin!.username})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Live Location: ${_selectedFriendPin!.sharedLocation}\nGPS: ${_selectedFriendPin!.latitude.toStringAsFixed(4)}° N, ${_selectedFriendPin!.longitude.toStringAsFixed(4)}° E',
              ),
              isThreeLine: true,
            ),
          ),
        ],

        if (_selectedPersonalPin != null) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _selectedPersonalPin!.type.color,
                child: Icon(
                  _selectedPersonalPin!.type.icon,
                  color: Colors.white,
                ),
              ),
              title: Text(
                '${_selectedPersonalPin!.type.label}: ${_selectedPersonalPin!.zoneLabel}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_selectedPersonalPin!.note}\nSaved at ${_selectedPersonalPin!.latitude.toStringAsFixed(4)}° N, ${_selectedPersonalPin!.longitude.toStringAsFixed(4)}° E',
              ),
              isThreeLine: true,
              trailing: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF2E93),
                ),
                onPressed: () => _unpinLocation(_selectedPersonalPin!.type),
                icon: const Icon(Icons.location_off_rounded, size: 18),
                label: const Text('Unpin'),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Auto-Detect Pin My Spot Row (with Location Enabled requirement)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Auto-Detect & Pin Location',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              widget.appState.isDeviceLocationEnabled
                  ? 'GPS Ready'
                  : 'Requires Location',
              style: TextStyle(
                fontSize: 12,
                color: widget.appState.isDeviceLocationEnabled
                    ? const Color(0xFF10B981)
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PersonalPinType.values.map((type) {
            final existing =
                personalPins.where((p) => p.type == type).firstOrNull;
            return InputChip(
              avatar: Icon(type.icon, size: 17, color: type.color),
              selected: existing != null,
              showCheckmark: false,
              label: Text(
                existing != null
                    ? '${type.label} ✓ (Auto-Pinned)'
                    : 'Auto-Pin ${type.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _triggerAutoDetectPin(type, existing),
              onDeleted:
                  existing != null ? () => _unpinLocation(type) : null,
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              deleteButtonTooltipMessage: 'Unpin ${type.label}',
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Stage Lineup
        Text(
          'Stage Lineup',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        ...fest.lineup.map((slot) {
          final isStarred = widget.appState.isSlotStarred(slot.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: fest.primaryColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: fest.primaryColor,
                ),
              ),
              title: Text(
                slot.artist,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text('${slot.dayLabel} • ${slot.timeRange} • ${slot.stageName}'),
              trailing: IconButton(
                onPressed: () => widget.appState.toggleStarredSlot(slot.id),
                icon: Icon(
                  isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isStarred ? const Color(0xFFFF2E93) : null,
                  size: 26,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _FullScreenMapScreen extends StatefulWidget {
  const _FullScreenMapScreen({
    required this.appState,
    required this.festival,
  });

  final AppState appState;
  final Festival festival;

  @override
  State<_FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<_FullScreenMapScreen> {
  mbx.MapboxMap? _mapboxMap;
  StreamSubscription<Position>? _positionSub;
  Position? _liveGpsPosition;
  mbx.PointAnnotationManager? _pointManager;
  mbx.PointAnnotation? _userGpsAnnotation;
  mbx.CircleAnnotationManager? _circleManager;
  mbx.CircleAnnotation? _userCircleHalo;
  mbx.CircleAnnotation? _userCircleCore;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _startLocationTracking() async {
    if (!widget.appState.isDeviceLocationEnabled) return;

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
    } catch (_) {}

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() => _liveGpsPosition = pos);
        _updateFullScreenUserMarker(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() => _liveGpsPosition = pos);
        _updateFullScreenUserMarker(pos.latitude, pos.longitude);
      }
    });
  }

  void _updateFullScreenUserMarker(double lat, double lng) async {
    // 1. Glowing high-visibility circular target
    if (_circleManager != null) {
      try {
        final pt = mbx.Point(coordinates: mbx.Position(lng, lat));
        if (_userCircleHalo != null && _userCircleCore != null) {
          _userCircleHalo!.geometry = pt;
          _userCircleCore!.geometry = pt;
          await _circleManager!.update(_userCircleHalo!);
          await _circleManager!.update(_userCircleCore!);
        } else {
          _userCircleHalo = await _circleManager!.create(
            mbx.CircleAnnotationOptions(
              geometry: pt,
              circleRadius: 18.0,
              circleColor: const Color(0x5500E5FF).toARGB32(),
              circleStrokeWidth: 2.0,
              circleStrokeColor: const Color(0xFF00E5FF).toARGB32(),
            ),
          );
          _userCircleCore = await _circleManager!.create(
            mbx.CircleAnnotationOptions(
              geometry: pt,
              circleRadius: 7.5,
              circleColor: const Color(0xFF00E5FF).toARGB32(),
              circleStrokeWidth: 2.5,
              circleStrokeColor: Colors.white.toARGB32(),
            ),
          );
        }
      } catch (_) {}
    }

    // 2. You pin badge
    if (_pointManager != null) {
      try {
        final pt = mbx.Point(coordinates: mbx.Position(lng, lat));
        if (_userGpsAnnotation != null) {
          _userGpsAnnotation!.geometry = pt;
          await _pointManager!.update(_userGpsAnnotation!);
        } else {
          final gpsBytes = await _generatePinMarkerPng(
            symbol: '📍',
            color: const Color(0xFF00E5FF),
          );
          _userGpsAnnotation = await _pointManager!.create(
            mbx.PointAnnotationOptions(
              geometry: pt,
              image: gpsBytes,
              iconSize: 0.75,
              textField: 'You',
              textColor: const Color(0xFF00E5FF).toARGB32(),
              textSize: 12.0,
              textOffset: [0.0, 1.8],
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _onFullScreenMapboxCreated(mbx.MapboxMap mapbox) async {
    _mapboxMap = mapbox;
    final lat = widget.festival.latitude;
    final lng = widget.festival.longitude;
    mapbox.setCamera(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(lng, lat)),
        zoom: 16.5,
        pitch: 58.0,
        bearing: -25.0,
      ),
    );

    // Turn on live Mapbox location component with pulsing GPS puck
    if (widget.appState.isDeviceLocationEnabled) {
      try {
        await mapbox.location.updateSettings(
          mbx.LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            pulsingColor: const Color(0xFF00E5FF).toARGB32(),
            showAccuracyRing: true,
            accuracyRingColor: const Color(0x3300E5FF).toARGB32(),
            puckBearingEnabled: true,
          ),
        );
      } catch (_) {}
    }

    try {
      _circleManager = await mapbox.annotations.createCircleAnnotationManager();

      // 1. Highlight festival perimeter with color
      final polyManager = await mapbox.annotations.createPolygonAnnotationManager();
      const deltaLat = 0.0035;
      const deltaLng = 0.0055;
      polyManager.create(
        mbx.PolygonAnnotationOptions(
          geometry: mbx.Polygon(coordinates: [
            [
              mbx.Position(lng - deltaLng, lat - deltaLat),
              mbx.Position(lng + deltaLng, lat - deltaLat * 0.8),
              mbx.Position(lng + deltaLng * 0.9, lat + deltaLat),
              mbx.Position(lng - deltaLng * 0.8, lat + deltaLat * 1.1),
              mbx.Position(lng - deltaLng, lat - deltaLat),
            ]
          ]),
          fillColor: const Color(0xFF7C3AED).withValues(alpha: 0.28).toARGB32(),
          fillOutlineColor: const Color(0xFFFF2E93).toARGB32(),
        ),
      );

      _pointManager = await mapbox.annotations.createPointAnnotationManager();

      // 2. Add visual icons for spots (venue facilities: water, toilet, stage, etc.)
      for (final pin in widget.festival.mapPins) {
        final pLat = lat + (pin.y - 0.5) * 0.005;
        final pLng = lng + (pin.x - 0.5) * 0.007;
        final symbol = _categorySymbol(pin.category);
        final iconBytes = await _generatePinMarkerPng(
          symbol: symbol,
          color: pin.category.color,
        );

        _pointManager!.create(
          mbx.PointAnnotationOptions(
            geometry: mbx.Point(coordinates: mbx.Position(pLng, pLat)),
            image: iconBytes,
            iconSize: 0.70,
            textField: pin.title,
            textColor: Colors.white.toARGB32(),
            textSize: 12.0,
            textOffset: [0.0, 1.8],
          ),
        );
      }

      // 3. Add personal pins (car, tent, bike)
      final myPins = widget.appState.getPersonalPins(widget.festival.id);
      for (final pPin in myPins) {
        final pLat = lat + (pPin.y - 0.5) * 0.005;
        final pLng = lng + (pPin.x - 0.5) * 0.007;
        final symbol = pPin.type == PersonalPinType.car
            ? '🚗'
            : pPin.type == PersonalPinType.bike
                ? '🚲'
                : '⛺';
        final iconBytes = await _generatePinMarkerPng(
          symbol: symbol,
          color: pPin.type.color,
        );
        _pointManager!.create(
          mbx.PointAnnotationOptions(
            geometry: mbx.Point(coordinates: mbx.Position(pLng, pLat)),
            image: iconBytes,
            iconSize: 0.70,
            textField: pPin.zoneLabel,
            textColor: const Color(0xFF00E5FF).toARGB32(),
            textSize: 11.5,
            textOffset: [0.0, 1.8],
          ),
        );
      }

      // 4. Add friend pins if location enabled
      if (widget.appState.isDeviceLocationEnabled) {
        for (final friend in widget.appState.myFriends) {
          if (friend.sharedLocation != null) {
            final fLat = lat + (friend.venueY - 0.5) * 0.005;
            final fLng = lng + (friend.venueX - 0.5) * 0.007;
            final iconBytes = await _generatePinMarkerPng(
              symbol: friend.name.characters.first,
              color: friend.avatarColor,
            );
            _pointManager!.create(
              mbx.PointAnnotationOptions(
                geometry: mbx.Point(coordinates: mbx.Position(fLng, fLat)),
                image: iconBytes,
                iconSize: 0.70,
                textField: friend.name,
                textColor: Colors.white.toARGB32(),
                textSize: 11.0,
                textOffset: [0.0, 1.8],
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (_liveGpsPosition != null) {
      _updateFullScreenUserMarker(_liveGpsPosition!.latitude, _liveGpsPosition!.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fest = widget.festival;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131124),
        title: Text(
          '${fest.name} Venue Map',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Recenter Venue',
            onPressed: () {
              _mapboxMap?.setCamera(
                mbx.CameraOptions(
                  center: mbx.Point(
                    coordinates: mbx.Position(fest.longitude, fest.latitude),
                  ),
                  zoom: 16.5,
                  pitch: 58.0,
                  bearing: -25.0,
                ),
              );
            },
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF00E5FF)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF161426),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pinch_rounded, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Pinch or scroll to zoom & explore',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                if (widget.appState.isDeviceLocationEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'GPS Live',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: mbx.MapWidget(
                    key: ValueKey('fullscreen_mapbox_${widget.festival.id}'),
                    styleUri: kCustomFestivalMapboxStyleUri,
                    viewport: mbx.CameraViewportState(
                      center: mbx.Point(coordinates: mbx.Position(widget.festival.longitude, widget.festival.latitude)),
                      zoom: 16.5,
                      pitch: 58.0,
                      bearing: -25.0,
                    ),
                    onMapCreated: _onFullScreenMapboxCreated,
                  ),
                ),

                // Floating Locate Me FAB
                if (widget.appState.isDeviceLocationEnabled)
                  Positioned(
                    bottom: 76,
                    right: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'fullscreen_gps_fab_${widget.festival.id}',
                      backgroundColor: const Color(0xFF131124),
                      foregroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      onPressed: () {
                        if (_liveGpsPosition != null) {
                          _mapboxMap?.flyTo(
                            mbx.CameraOptions(
                              center: mbx.Point(
                                coordinates: mbx.Position(
                                  _liveGpsPosition!.longitude,
                                  _liveGpsPosition!.latitude,
                                ),
                              ),
                              zoom: 17.5,
                              pitch: 45.0,
                              bearing: 0.0,
                            ),
                            mbx.MapAnimationOptions(duration: 1000),
                          );
                        } else {
                          _startLocationTracking();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Acquiring live GPS fix...')),
                          );
                        }
                      },
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ),

                // Woov-style Floating Quick-Jump Stage & Spot Bar
                Positioned(
                  bottom: 24,
                  left: 12,
                  right: 12,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickFocusPill(
                          icon: '🏟️',
                          label: 'Overview',
                          onTap: () {
                            _mapboxMap?.flyTo(
                              mbx.CameraOptions(
                                center: mbx.Point(
                                  coordinates: mbx.Position(fest.longitude, fest.latitude),
                                ),
                                zoom: 16.5,
                                pitch: 58.0,
                                bearing: -25.0,
                              ),
                              mbx.MapAnimationOptions(duration: 1200),
                            );
                          },
                        ),
                        if (widget.appState.isDeviceLocationEnabled)
                          _buildQuickFocusPill(
                            icon: '📍',
                            label: 'My Location',
                            onTap: () {
                              if (_liveGpsPosition != null) {
                                _mapboxMap?.flyTo(
                                  mbx.CameraOptions(
                                    center: mbx.Point(
                                      coordinates: mbx.Position(
                                        _liveGpsPosition!.longitude,
                                        _liveGpsPosition!.latitude,
                                      ),
                                    ),
                                    zoom: 17.5,
                                    pitch: 45.0,
                                    bearing: 0.0,
                                  ),
                                  mbx.MapAnimationOptions(duration: 1000),
                                );
                              } else {
                                _startLocationTracking();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Acquiring live GPS fix...')),
                                );
                              }
                            },
                          ),
                        ...fest.mapPins.where((p) => p.category == MapPinCategory.stage).map((stage) {
                          return _buildQuickFocusPill(
                            icon: '🎵',
                            label: stage.title,
                            onTap: () {
                              final sLat = fest.latitude + (stage.y - 0.5) * 0.005;
                              final sLng = fest.longitude + (stage.x - 0.5) * 0.007;
                              _mapboxMap?.flyTo(
                                mbx.CameraOptions(
                                  center: mbx.Point(coordinates: mbx.Position(sLng, sLat)),
                                  zoom: 17.5,
                                  pitch: 62.0,
                                  bearing: 15.0,
                                ),
                                mbx.MapAnimationOptions(duration: 1200),
                              );
                            },
                          );
                        }),
                        _buildQuickFocusPill(
                          icon: '💧',
                          label: 'Water Points',
                          onTap: () {
                            final waterPin = fest.mapPins.firstWhere(
                              (p) => p.category == MapPinCategory.water,
                              orElse: () => fest.mapPins.first,
                            );
                            final wLat = fest.latitude + (waterPin.y - 0.5) * 0.005;
                            final wLng = fest.longitude + (waterPin.x - 0.5) * 0.007;
                            _mapboxMap?.flyTo(
                              mbx.CameraOptions(
                                center: mbx.Point(coordinates: mbx.Position(wLng, wLat)),
                                zoom: 17.8,
                                pitch: 55.0,
                                bearing: 0.0,
                              ),
                              mbx.MapAnimationOptions(duration: 1200),
                            );
                          },
                        ),
                        if (widget.appState.isDeviceLocationEnabled)
                          _buildQuickFocusPill(
                            icon: '📍',
                            label: 'My Spot',
                            onTap: () {
                              final targetLng = _liveGpsPosition?.longitude ?? fest.longitude;
                              final targetLat = _liveGpsPosition?.latitude ?? fest.latitude;
                              _mapboxMap?.flyTo(
                                mbx.CameraOptions(
                                  center: mbx.Point(
                                    coordinates: mbx.Position(targetLng, targetLat),
                                  ),
                                  zoom: 18.0,
                                  pitch: 60.0,
                                  bearing: 0.0,
                                ),
                                mbx.MapAnimationOptions(duration: 1000),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFocusPill({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF131124).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
