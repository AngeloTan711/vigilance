import 'package:flutter/material.dart';
import '../../models/emergency_alert.dart';
import '../../services/local_alert_queue.dart';
import '../../utils/constants.dart'; // needed for the AlertStatusX.discreetLabel extension getter

/// "View own emergency history" (original spec, Student capabilities).
///
/// NOTE — gap flagged rather than guessed around: the approved API spec
/// (docs/ARCHITECTURE.md §4) has no GET endpoint for "my own alert list" —
/// only GET /alerts (responder/admin only) and GET /alerts/{id} (owner OR
/// responder/admin, single alert). This screen reads the on-device local
/// queue instead, which does hold every alert this device has created
/// (real and test). That covers this device's history but not alerts
/// created from a different device on the same account. A
/// `GET /api/alerts/mine` endpoint would close that gap — call it out for
/// Phase 3 rather than silently adding it to the backend spec here.
class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});
  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  final _queue = LocalAlertQueue();
  List<EmergencyAlert> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _queue.loadAll();
    all.sort((a, b) => b.activatedAt.compareTo(a.activatedAt));
    setState(() {
      _alerts = all;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(child: Text('No alerts on this device yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (context, i) {
                      final a = _alerts[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(a.isTest ? Icons.science_outlined : Icons.shield_outlined),
                          title: Text(a.isTest ? 'TEST ALERT' : 'Emergency Alert'),
                          subtitle: Text(
                              '${a.activatedAt.toLocal()}\nStatus: ${a.status.discreetLabel} · ${a.deliveryStatus.name}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
