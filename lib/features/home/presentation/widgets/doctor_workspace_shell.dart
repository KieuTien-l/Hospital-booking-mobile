import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigator.currentState?.pop(result),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const DoctorHomePage()),
    ),
  );
}
