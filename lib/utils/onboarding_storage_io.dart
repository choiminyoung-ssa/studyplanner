import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_storage_base.dart';

OnboardingStorage createOnboardingStorageImpl() => _IoOnboardingStorage();

class _IoOnboardingStorage implements OnboardingStorage {
  static const _key = 'onboarding_seen';

  @override
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> setSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
