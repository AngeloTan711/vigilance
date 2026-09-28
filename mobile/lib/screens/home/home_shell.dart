import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/protection_provider.dart';
import '../contacts/contacts_screen.dart';
import '../emergency/emergency_activation_screen.dart';
import '../settings/settings_screen.dart';
import 'alerts_history_screen.dart';
import 'protection_screen.dart';

/// Per spec §24: bottom navigation is Home/Alerts/Contacts/Settings, but the
/// emergency trigger must not depend on which tab is showing. ProtectionProvider
/// keeps running (it's provided above this widget in main.dart, not owned by
/// any one tab), and this shell listens for emergencyTriggered regardless of
/// the selected index and jumps straight to EmergencyActivationScreen.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    ProtectionScreen(),
    AlertsHistoryScreen(),
    ContactsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProtectionProvider>(
      builder: (context, protection, _) {
        if (protection.emergencyTriggered) {
          protection.acknowledgeTrigger();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyActivationScreen(isTest: false)),
            );
          });
        }
        return Scaffold(
          body: IndexedStack(index: _index, children: _tabs),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Alerts'),
              BottomNavigationBarItem(icon: Icon(Icons.contacts_outlined), label: 'Contacts'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}
