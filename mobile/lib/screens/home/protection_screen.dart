import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/pulse_provider.dart';
import '../../providers/protection_provider.dart';
import '../contacts/contacts_screen.dart';
import '../emergency/emergency_activation_screen.dart';
import '../pulse/pulse_setup_screen.dart';
import '../settings/settings_screen.dart';

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});
  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProtectionProvider>().refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final protection = context.watch<ProtectionProvider>();
    final pulse = context.watch<PulseProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('VIGILANCE', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Center(
                child: Chip(
                  backgroundColor: protection.isProtectionEnabled
                      ? VigilanceColors.safeGreen.withValues(alpha: 0.2)
                      : VigilanceColors.navySurface,
                  label: Text(
                    protection.isProtectionEnabled ? 'PROTECTION ACTIVE' : 'PROTECTION OFF',
                    style: TextStyle(
                      color: protection.isProtectionEnabled ? VigilanceColors.safeGreen : VigilanceColors.mutedWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(protection.monitoringScopeLabel,
                    style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatusRow(label: 'Pulse', ok: pulse.isConfigured, okLabel: 'Ready', badLabel: 'Not configured'),
                      _StatusRow(label: 'GPS', ok: protection.gpsAvailable, okLabel: 'Available', badLabel: 'Unavailable'),
                      _StatusRow(label: 'Internet', ok: protection.internetConnected, okLabel: 'Connected', badLabel: 'Offline'),
                      _StatusRow(label: 'SMS', ok: protection.smsAvailable, okLabel: 'Available', badLabel: 'Unavailable'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Enable Protection'),
                value: protection.isProtectionEnabled,
                onChanged: (val) async {
                  if (!pulse.isConfigured) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Set up your Pulse first.')));
                    return;
                  }
                  if (val) {
                    await protection.enable(pulse.config!);
                  } else {
                    await protection.disable();
                  }
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: VigilanceColors.emergencyRed),
                onPressed: pulse.isConfigured
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EmergencyActivationScreen(isTest: true)),
                        )
                    : null,
                child: const Text('TEST EMERGENCY'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PulseSetupScreen())),
                      child: const Text('PULSE SETTINGS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())),
                      child: const Text('CONTACTS'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: const Text('SETTINGS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String okLabel;
  final String badLabel;
  const _StatusRow({required this.label, required this.ok, required this.okLabel, required this.badLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.circle, size: 14,
                  color: ok ? VigilanceColors.safeGreen : VigilanceColors.warnAmber),
              const SizedBox(width: 6),
              Text(ok ? okLabel : badLabel, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
