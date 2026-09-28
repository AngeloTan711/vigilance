import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/emergency_alert.dart';
import '../utils/constants.dart'; // needed directly for DeliveryStatus — not re-exported by emergency_alert.dart

/// Persists alerts locally so an emergency is never lost to a killed app or
/// a device that stayed offline — this is the "store_alert_locally() /
/// retry_when_connection_available()" branch of the pseudocode in the
/// original spec §6, and the QUEUED delivery_status described in
/// docs/ARCHITECTURE.md §2.
class LocalAlertQueue {
  static Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'vigilance_alerts.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE alerts (
            local_id TEXT PRIMARY KEY,
            payload TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> save(EmergencyAlert alert) async {
    final db = await _database();
    await db.insert(
      'alerts',
      {'local_id': alert.localId, 'payload': jsonEncode(alert.toLocalJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EmergencyAlert>> loadAll() async {
    final db = await _database();
    final rows = await db.query('alerts');
    return rows
        .map((row) => EmergencyAlert.fromLocalJson(jsonDecode(row['payload'] as String)))
        .toList();
  }

  /// Alerts that still need a delivery attempt or a sync — anything not yet
  /// DeliveryStatus.delivered. Used on app start and on connectivity-restore
  /// to drive retries (§26 Offline-First Behavior).
  Future<List<EmergencyAlert>> loadUndelivered() async {
    final all = await loadAll();
    return all.where((a) => a.deliveryStatus != DeliveryStatus.delivered).toList();
  }

  Future<void> remove(String localId) async {
    final db = await _database();
    await db.delete('alerts', where: 'local_id = ?', whereArgs: [localId]);
  }
}
