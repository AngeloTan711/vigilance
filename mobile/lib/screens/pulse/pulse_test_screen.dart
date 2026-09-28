import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pulse_provider.dart';

/// SCREEN 6. TEST_MODE is enforced structurally: this screen only ever
/// calls PulseProvider.testPulse(), which routes through
/// GestureDetectionService.testOnce() — a code path that has no access to
/// AlertService and therefore cannot create a real alert, per the class doc
/// on GestureDetectionService.
class PulseTestScreen extends StatelessWidget {
  const PulseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pulse = context.watch<PulseProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Test Your Pulse')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text('TEST YOUR PULSE', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('Perform your emergency gesture now.'),
              const SizedBox(height: 40),
              if (pulse.isTesting) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Waiting for gesture...'),
              ] else if (pulse.lastTestResult == PulseTestResult.recognized) ...[
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary, size: 56),
                const SizedBox(height: 16),
                Text('PULSE RECOGNIZED', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Your emergency signal is working.'),
              ] else if (pulse.lastTestResult == PulseTestResult.notRecognized) ...[
                const Icon(Icons.error_outline, color: Colors.amber, size: 56),
                const SizedBox(height: 16),
                const Text('Gesture not recognized.'),
                const Text('Try again.'),
              ],
              const Spacer(),
              if (pulse.lastTestResult == PulseTestResult.recognized)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CONTINUE'),
                )
              else
                ElevatedButton(
                  onPressed: pulse.isTesting ? null : () => pulse.testPulse(),
                  child: const Text('START TEST'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
