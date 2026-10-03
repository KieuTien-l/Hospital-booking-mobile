import 'package:shared_preferences/shared_preferences.dart';

/// Stores only small, non-sensitive preferences. Never store credentials here.
class AppPreferences {
  AppPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const onboardingCompletedKey = 'onboardingCompleted';
  final SharedPreferencesAsync _preferences;

  Future<bool> isOnboardingCompleted() async {
    return await _preferences.getBool(onboardingCompletedKey) ?? false;
  }

  Future<void> completeOnboarding() {
    return _preferences.setBool(onboardingCompletedKey, true);
  }
}
