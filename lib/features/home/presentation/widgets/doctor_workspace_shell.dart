import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/unconfigured_doctor_workspace_repository.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../pages/doctor_home_page.dart';

/// All doctor routes are disposed together when AuthGate removes this subtree.
class DoctorWorkspaceShell extends StatefulWidget {
  const DoctorWorkspaceShell({super.key});
  @override
  State<DoctorWorkspaceShell> createState() => _DoctorWorkspaceShellState();
}

class _DoctorWorkspaceShellState extends State<DoctorWorkspaceShell> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    // The app registers the real repository above AuthGate. Keeping a
    // fail-closed fallback lets isolated previews/tests render the doctor
    // shell without silently falling back to direct Firestore data.
    final repository =
        context.read<DoctorWorkspaceRepository?>() ??
        const UnconfiguredDoctorWorkspaceRepository();
    return ChangeNotifierProvider(
      key: ValueKey(userId),
      create: (context) =>
          DoctorWorkspaceController(repository: repository, userId: userId),
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (result) => _navigator.currentState?.pop(result),
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const DoctorHomePage()),
        ),
      ),
    );
  }
}
