import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../domain/entities/specialty.dart';
import '../../domain/repositories/specialty_repository.dart';

class SpecialtyController extends ViewStateController {
  SpecialtyController(this._repository);
  final SpecialtyRepository _repository;
  StreamSubscription<List<Specialty>>? _subscription;
  List<Specialty> _specialties = const [];
  List<Specialty> get specialties => _specialties;
  Future<void> loadSpecialties() async {
    _specialties = const [];
    final token = beginRequest();
    try {
      await _subscription?.cancel();
      if (!isCurrent(token)) return;
      _subscription = _repository.watchSpecialties().listen(
        (values) {
          if (!isCurrent(token)) return;
          _specialties = List.unmodifiable(values);
          setState(values.isEmpty ? ViewState.empty : ViewState.success);
        },
        onError: (Object error) {
          if (isCurrent(token)) setState(ViewState.error, error);
        },
      );
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
