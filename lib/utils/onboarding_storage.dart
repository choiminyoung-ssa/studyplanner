import 'onboarding_storage_base.dart';
import 'onboarding_storage_stub.dart'
    if (dart.library.html) 'onboarding_storage_web.dart'
    if (dart.library.io) 'onboarding_storage_io.dart';

OnboardingStorage createOnboardingStorage() => createOnboardingStorageImpl();
