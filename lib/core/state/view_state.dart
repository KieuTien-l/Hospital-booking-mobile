import 'package:flutter/foundation.dart';

enum ViewState {
  initial,
  loading,
  success,
  empty,
  error;

  static const idle = initial;
}

/// Request tokens prevent stale responses and notifications after disposal.
abstract class ViewStateController extends ChangeNotifier {
  ViewState _status = ViewState.initial;
  String? _errorMessage;
  int _request = 0;
  bool _disposed = false;
  ViewState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => status == ViewState.loading;
  bool get isSuccess => status == ViewState.success;
  bool get isEmpty => status == ViewState.empty;
  bool get hasError => status == ViewState.error;
  int beginRequest() {
    final token = ++_request;
    setState(ViewState.loading);
    return token;
  }

  bool isCurrent(int token) => !_disposed && token == _request;
  void invalidateRequests() {
    _request++;
  }

  void setState(ViewState value, [Object? error]) {
    if (_disposed) return;
    _status = value;
    _errorMessage = error?.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }

  void clearError() => setState(ViewState.initial);
  @override
  void dispose() {
    _disposed = true;
    invalidateRequests();
    super.dispose();
  }
}
