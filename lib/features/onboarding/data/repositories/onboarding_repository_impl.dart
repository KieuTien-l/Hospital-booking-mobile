import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/app_preferences.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<bool> isOnboardingCompleted() => _preferences.isOnboardingCompleted();

  @override
  Future<void> completeOnboarding() => _preferences.completeOnboarding();
}
