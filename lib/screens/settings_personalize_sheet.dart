import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/sample_data.dart';

class SettingsPersonalizeSheet extends StatelessWidget {
  const SettingsPersonalizeSheet({
    super.key,
    required this.appState,
    this.onApplyPersonalizedFeed,
  });

  final AppState appState;
  final VoidCallback? onApplyPersonalizedFeed;

  static Future<void> show(
    BuildContext context,
    AppState appState, {
    VoidCallback? onApplyPersonalizedFeed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: SettingsPersonalizeSheet(
            appState: appState,
            onApplyPersonalizedFeed: () {
              Navigator.pop(ctx);
              onApplyPersonalizedFeed?.call();
            },
          ),
        ),
      ),
    );
  }

  static const List<String> _cities = [
    'All Cities',
    'Eindhoven',
    'Rotterdam',
    'Tilburg',
    'Arnhem',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final isDark = appState.isHighContrastNightMode;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
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
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Settings & Personalize Discovery',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 1. Theme Option
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.palette_outlined, color: Color(0xFFA855F7)),
                          SizedBox(width: 8),
                          Text(
                            'Theme Option',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Neon Dark'),
                          ),
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Daylight Clean'),
                          ),
                        ],
                        selected: {isDark},
                        onSelectionChanged: (sel) {
                          if (sel.first != isDark) {
                            appState.toggleNightMode();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Sound Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(
                          Icons.volume_up_rounded,
                          color: Color(0xFF00E5FF),
                        ),
                        title: const Text(
                          'App Sound & Alert Effects',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        value: appState.soundEffectsEnabled,
                        onChanged: (v) =>
                            appState.setSoundSettings(enabled: v),
                      ),
                      if (appState.soundEffectsEnabled) ...[
                        Row(
                          children: [
                            const Icon(Icons.volume_mute_rounded, size: 18),
                            Expanded(
                              child: Slider(
                                value: appState.soundVolume,
                                onChanged: (v) =>
                                    appState.setSoundSettings(volume: v),
                              ),
                            ),
                            Text(
                              '${(appState.soundVolume * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Text Size Option
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.format_size_rounded,
                            color: Color(0xFFFF2E93),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Text Size',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0.9, label: Text('Small')),
                          ButtonSegment(value: 1.0, label: Text('Normal')),
                          ButtonSegment(value: 1.15, label: Text('Large')),
                          ButtonSegment(value: 1.25, label: Text('XL')),
                        ],
                        selected: {appState.textScale},
                        onSelectionChanged: (sel) =>
                            appState.setTextScale(sel.first),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Personalize Discovery Page (Music Types + Location)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFF2E93),
                        ),
                        title: const Text(
                          'Personalized Discovery Feed',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                        subtitle: const Text(
                          'Filter Discover to only show your chosen music types & locations',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: appState.isPersonalizedDiscoveryEnabled,
                        onChanged: (v) =>
                            appState.setPersonalizedDiscovery(enabled: v),
                      ),
                      const Divider(height: 18),
                      const Text(
                        'Choose Music & Festival Types:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SampleData.allGenres.map((genre) {
                          final selected =
                              appState.selectedGenres.contains(genre);
                          return FilterChip(
                            selected: selected,
                            label: Text(genre),
                            onSelected: (_) {
                              appState.togglePreferredGenre(genre);
                              appState.setPersonalizedDiscovery(enabled: true);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Preferred Location / City:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _cities.map((city) {
                          final isSelected =
                              appState.preferredDiscoveryCity == city;
                          return ChoiceChip(
                            selected: isSelected,
                            label: Text(city),
                            onSelected: (_) {
                              appState.setPersonalizedDiscovery(
                                enabled: true,
                                preferredCity: city,
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Max Distance: ${appState.maxPreferredDistanceKm.round()} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Slider(
                        value: appState.maxPreferredDistanceKm,
                        min: 10,
                        max: 150,
                        divisions: 14,
                        onChanged: (v) {
                          appState.updateAiPreferences(maxDistanceKm: v);
                          appState.setPersonalizedDiscovery(enabled: true);
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2E93),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: onApplyPersonalizedFeed,
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text(
                            'Show My Personalized Discovery Page',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
