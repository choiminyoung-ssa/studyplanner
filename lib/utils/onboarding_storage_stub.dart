import 'onboarding_storage_base.dart';

OnboardingStorage createOnboardingStorageImpl() => _StubOnboardingStorage();

class _StubOnboardingStorage implements OnboardingStorage {
  bool _seen = false;

  @override
  Future<bool> hasSeenOnboarding() async => _seen;

  @override
  Future<void> setSeenOnboarding(bool value) async {
    _seen = value;
  }
}
