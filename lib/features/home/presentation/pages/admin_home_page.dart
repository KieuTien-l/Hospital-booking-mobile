import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/presentation/admin_workspace.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_accountId != auth.currentUser?.id) {
      _accountId = auth.currentUser?.id;
      _navigator = GlobalKey<NavigatorState>();
    }
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => _navigator.currentState?.pop(result),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => AdminWorkspace(
            userName: auth.currentUser?.fullName ?? 'Quản trị viên',
            onLogout: auth.logout,
          ),
        ),
      ),
    );
  }
}
