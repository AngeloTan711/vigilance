import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/emergency_provider.dart';
import 'cloak_mode_screen.dart';

/// SCREEN 8. Per spec: no confirmation button, the workflow runs
/// immediately. This screen exists only for the few seconds delivery takes
/// (capture GPS, attempt CLOUD/SMS) before handing off to Cloak Mode — it is
/// intentionally brief and not part of Cloak Mode's discreet design, since
/// the transition to Cloak Mode happens automatically and fast.
class EmergencyActivationScreen extends StatefulWidget {
  final bool isTest;
  const EmergencyActivationScreen({super.key, this.isTest = false});

  @override
  State<EmergencyActivationScreen> createState() => _EmergencyActivationScreenState();
}

class _EmergencyActivationScreenState extends State<EmergencyActivationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final user = context.read<AuthProvider>().user!;
    final contacts = context.read<ContactsProvider>().contacts;
    final emergency = context.read<EmergencyProvider>();

    await emergency.activate(user: user, contacts: contacts, isTest: widget.isTest);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CloakModeScreen(isTest: widget.isTest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Neutral, low-key screen — not a flashing red "EMERGENCY" screen, in
    // keeping with Cloak Mode's spirit even at this brief in-between step.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
