import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/emergency_provider.dart';
import '../../utils/constants.dart';
import '../home/home_shell.dart';

/// SCREEN 9 (Cloak Mode) + SCREEN 10 (Emergency Status), combined per spec:
/// the discreet status line lives inside the same neutral "Notes" surface,
/// never a banner reading SOS/EMERGENCY/HELP, never flashing red.
///
/// A real Notes app would let the user keep typing; this screen is a
/// believable-at-a-glance stand-in, not a functioning notes editor —
/// building a full fake-notes-app editor is out of Phase 2 scope and would
/// be security-through-obscurity theater without changing the underlying
/// safety property (the alert is already sent regardless of what's on
/// screen).
class CloakModeScreen extends StatelessWidget {
  final bool isTest;
  const CloakModeScreen({super.key, this.isTest = false});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VigilanceTheme.cloak,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: const Text('Notes'),
          actions: [
            // A deliberately unremarkable exit — returns to the normal app.
            // Ending Cloak Mode does NOT cancel the alert; cancellation is a
            // separate, explicit action (see _CancelDialog) so a nearby
            // threat forcing the phone closed can't silently kill a real
            // alert.
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeShell()),
                (route) => false,
              ),
            ),
          ],
        ),
        body: Consumer<EmergencyProvider>(
          builder: (context, emergency, _) {
            final alert = emergency.currentAlert;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  const Text('Remember to review your schedule.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      TimeOfDay.now().format(context),
                      style: const TextStyle(color: Colors.black38, fontSize: 12),
                    ),
                  ),
                  const Divider(height: 48),
                  // Discreetly worded status — SCREEN 10. Wording stays low-key
                  // per spec; icons use a checkmark/dot, not alarm imagery.
                  Text('Status', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  if (alert != null) ...[
                    _StatusLine(label: 'Alert Sent', done: true),
                    _StatusLine(
                      label: 'Response Team Notified',
                      done: alert.status.index >= AlertStatus.acknowledged.index,
                    ),
                    _StatusLine(
                      label: 'Responder En Route',
                      done: alert.status.index >= AlertStatus.responding.index,
                    ),
                    _StatusLine(
                      label: 'Incident Resolved',
                      done: alert.status == AlertStatus.resolved,
                    ),
                    if (isTest) ...[
                      const SizedBox(height: 16),
                      const Text('TEST ALERT — no responder was contacted.',
                          style: TextStyle(color: Colors.black45, fontSize: 12)),
                    ],
                    if (alert.status == AlertStatus.active || alert.status == AlertStatus.received) ...[
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () => _showCancelDialog(context, emergency),
                        child: const Text('This was a mistake', style: TextStyle(color: Colors.black45)),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, EmergencyProvider emergency) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this alert?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Alert')),
          TextButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              final ok = await emergency.cancelCurrentAlert(reasonCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted && ok) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeShell()),
                  (route) => false,
                );
              }
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final bool done;
  const _StatusLine({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(done ? Icons.check : Icons.fiber_manual_record, size: 14, color: done ? Colors.black54 : Colors.black26),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: done ? Colors.black87 : Colors.black38)),
        ],
      ),
    );
  }
}
