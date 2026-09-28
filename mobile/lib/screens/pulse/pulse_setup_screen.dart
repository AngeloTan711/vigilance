import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pulse_config.dart';
import '../../providers/pulse_provider.dart';
import 'pulse_test_screen.dart';

class PulseSetupScreen extends StatefulWidget {
  const PulseSetupScreen({super.key});
  @override
  State<PulseSetupScreen> createState() => _PulseSetupScreenState();
}

class _PulseSetupScreenState extends State<PulseSetupScreen> {
  PulseInputType _selected = PulseInputType.motionGesture;

  @override
  Widget build(BuildContext context) {
    final pulse = context.watch<PulseProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Pulse')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SET UP YOUR PULSE', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Your Pulse is your private emergency activation signal. '
                'Choose a gesture that you can perform discreetly.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _OptionTile(
                label: 'Tap Pattern',
                selected: _selected == PulseInputType.tapPattern,
                onTap: () => setState(() => _selected = PulseInputType.tapPattern),
              ),
              _OptionTile(
                label: 'Motion / Gesture',
                selected: _selected == PulseInputType.motionGesture,
                onTap: () => setState(() => _selected = PulseInputType.motionGesture),
              ),
              _OptionTile(
                label: 'Secret On-Screen Symbol',
                selected: _selected == PulseInputType.secretSymbol,
                onTap: () => setState(() => _selected = PulseInputType.secretSymbol),
              ),
              const Spacer(),
              if (pulse.isConfigured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Pulse saved successfully.',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                ),
              ElevatedButton(
                onPressed: pulse.isRecording
                    ? null
                    : () async {
                        await pulse.recordPulse(_selected);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Pulse saved successfully.')));
                      },
                child: pulse.isRecording
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('RECORD PULSE'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: pulse.isConfigured
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PulseTestScreen()))
                    : null,
                child: const Text('TEST PULSE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? Theme.of(context).colorScheme.secondary : Colors.transparent, width: 2),
      ),
      child: ListTile(
        title: Text(label),
        trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary) : null,
        onTap: onTap,
      ),
    );
  }
}
