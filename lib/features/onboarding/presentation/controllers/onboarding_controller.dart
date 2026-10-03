import '../../domain/repositories/onboarding_repository.dart';

class OnboardingController {
  const OnboardingController(this.repository);

  final OnboardingRepository repository;

  Future<bool> isOnboardingCompleted() async {
    try {
      return await repository.isOnboardingCompleted();
    } catch (_) {
      // Preserve the existing fallback when preferences cannot be read.
      return false;
    }
  }

  Future<void> completeOnboarding() => repository.completeOnboarding();
}
