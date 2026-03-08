import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedChallengerIdProvider = StateProvider<String?>((ref) => null);

class UserPreferences {
  final String lookingFor;
  final String idealDate;
  final String interests;
  final String communicationStyle;
  final String dealBreakers;
  final String aboutMe;

  const UserPreferences({
    this.lookingFor = '',
    this.idealDate = '',
    this.interests = '',
    this.communicationStyle = '',
    this.dealBreakers = '',
    this.aboutMe = '',
  });

  UserPreferences copyWith({
    String? lookingFor,
    String? idealDate,
    String? interests,
    String? communicationStyle,
    String? dealBreakers,
    String? aboutMe,
  }) {
    return UserPreferences(
      lookingFor: lookingFor ?? this.lookingFor,
      idealDate: idealDate ?? this.idealDate,
      interests: interests ?? this.interests,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      dealBreakers: dealBreakers ?? this.dealBreakers,
      aboutMe: aboutMe ?? this.aboutMe,
    );
  }
}

final userPreferencesProvider =
    StateProvider<UserPreferences>((ref) => const UserPreferences());
