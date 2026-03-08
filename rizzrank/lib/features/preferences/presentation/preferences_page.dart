import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/providers/app_state_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';

const _lookingForOptions = [
  'Casual dating',
  'Serious relationship',
  'Something in between',
  'Not sure yet',
  'Just practicing',
];

const _idealDateOptions = [
  'Coffee or drinks',
  'Dinner',
  'Movies',
  'Outdoor activities',
  'Adventures & travel',
  'Staying in',
  'Games & fun',
];

const _communicationStyles = [
  'Witty & playful',
  'Deep conversations',
  'Flirty & bold',
  'Chill & laid-back',
  'Intellectual',
  'Spontaneous',
];

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  late String _lookingFor;
  late String _idealDate;
  late String _communicationStyle;
  late String _gender;
  late String _preferredGender;
  late TextEditingController _interestsCtrl;
  late TextEditingController _aboutMeCtrl;
  late TextEditingController _dealBreakersCtrl;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(userPreferencesProvider);
    final user = ref.read(currentUserProvider).value;
    _lookingFor = prefs.lookingFor;
    _idealDate = prefs.idealDate;
    _communicationStyle = prefs.communicationStyle;
    _gender = user?.gender ?? '';
    _preferredGender = user?.preferredGender ?? '';
    _interestsCtrl = TextEditingController(text: prefs.interests);
    _aboutMeCtrl = TextEditingController(text: prefs.aboutMe);
    _dealBreakersCtrl = TextEditingController(text: prefs.dealBreakers);
  }

  @override
  void dispose() {
    _interestsCtrl.dispose();
    _aboutMeCtrl.dispose();
    _dealBreakersCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    ref.read(userPreferencesProvider.notifier).state = UserPreferences(
      lookingFor: _lookingFor,
      idealDate: _idealDate,
      communicationStyle: _communicationStyle,
      interests: _interestsCtrl.text,
      aboutMe: _aboutMeCtrl.text,
      dealBreakers: _dealBreakersCtrl.text,
    );
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await ref.read(databaseServiceProvider).updateUserProfile(
        user.uid,
        gender: _gender.isEmpty ? null : _gender,
        preferredGender: _preferredGender.isEmpty ? null : _preferredGender,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => _save(),
            icon: const Icon(LucideIcons.save, size: 18, color: AppTheme.primary),
            label: const Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.heart, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date Preferences',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Help us match you with the right vibes',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _GenderDropdownField(
              label: 'Your gender',
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
              traitsAsync: ref.watch(traitsProvider),
            ),
            const SizedBox(height: 20),
            _PreferredGenderDropdownField(
              label: 'Preferred AI character gender',
              value: _preferredGender,
              onChanged: (v) => setState(() => _preferredGender = v),
              traitsAsync: ref.watch(traitsProvider),
            ),
            const SizedBox(height: 20),
            _DropdownField(
              label: 'What are you looking for?',
              value: _lookingFor,
              options: _lookingForOptions,
              onChanged: (v) => setState(() => _lookingFor = v),
            ),
            const SizedBox(height: 20),
            _DropdownField(
              label: 'Ideal date idea',
              value: _idealDate,
              options: _idealDateOptions,
              onChanged: (v) => setState(() => _idealDate = v),
            ),
            const SizedBox(height: 20),
            _DropdownField(
              label: 'Communication style',
              value: _communicationStyle,
              options: _communicationStyles,
              onChanged: (v) => setState(() => _communicationStyle = v),
            ),
            const SizedBox(height: 20),
            _TextAreaField(
              label: 'Interests & hobbies',
              controller: _interestsCtrl,
              hint: 'e.g. Movies, hiking, cooking, music...',
            ),
            const SizedBox(height: 20),
            _TextAreaField(
              label: 'About me / What I bring',
              controller: _aboutMeCtrl,
              hint: 'A few words about yourself and what you bring to a date...',
            ),
            const SizedBox(height: 20),
            _TextAreaField(
              label: 'Deal breakers',
              controller: _dealBreakersCtrl,
              hint: 'Things that are non-negotiable for you...',
              maxLines: 2,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _save(),
                icon: const Icon(LucideIcons.save, size: 20),
                label: const Text('Save Preferences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                  shadowColor: AppTheme.primary.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _GenderDropdownField extends StatelessWidget {
  const _GenderDropdownField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.traitsAsync,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final AsyncValue<Map<String, List<String>>> traitsAsync;

  @override
  Widget build(BuildContext context) {
    final options = traitsAsync.valueOrNull?['genders'] ?? ['Man', 'Woman', 'Other'];
    return _DropdownField(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}

class _PreferredGenderDropdownField extends StatelessWidget {
  const _PreferredGenderDropdownField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.traitsAsync,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final AsyncValue<Map<String, List<String>>> traitsAsync;

  @override
  Widget build(BuildContext context) {
    final genders = traitsAsync.valueOrNull?['genders'] ?? ['Man', 'Woman', 'Other'];
    final options = ['Any', ...genders];
    return _DropdownField(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              hint: Text('Select...', style: TextStyle(color: Colors.white.withOpacity(0.3))),
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1634),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: options
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 3,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            )),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
