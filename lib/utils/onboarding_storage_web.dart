import 'dart:html' as html;
import 'onboarding_storage_base.dart';

OnboardingStorage createOnboardingStorageImpl() => _WebOnboardingStorage();

class _WebOnboardingStorage implements OnboardingStorage {
  static const _key = 'onboarding_seen';

  @override
  Future<bool> hasSeenOnboarding() async {
    return html.window.localStorage[_key] == 'true';
  }

  @override
  Future<void> setSeenOnboarding(bool value) async {
    html.window.localStorage[_key] = value ? 'true' : 'false';
  }
}
