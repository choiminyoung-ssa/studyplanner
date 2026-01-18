abstract class OnboardingStorage {
  Future<bool> hasSeenOnboarding();
  Future<void> setSeenOnboarding(bool value);
}
