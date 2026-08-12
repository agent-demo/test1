import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/observation.dart';

class LocalStore {
  LocalStore._(this._database);

  final Database _database;

  static Future<LocalStore> open() async {
    final databasePath = path.join(await getDatabasesPath(), 'crop_saathi.db');
    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE observations (
            id TEXT PRIMARY KEY,
            crop TEXT NOT NULL,
            captured_at TEXT NOT NULL,
            model_version TEXT NOT NULL,
            predictions TEXT NOT NULL,
            abstained INTEGER NOT NULL,
            abstain_reason TEXT,
            consent_for_training INTEGER NOT NULL,
            sync_status TEXT NOT NULL
          )
        ''');
      },
    );
    return LocalStore._(database);
  }

  Future<void> saveObservation(Observation observation) async {
    await _database.insert(
      'observations',
      observation.toStorage(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Observation>> listObservations() async {
    final rows = await _database.query('observations', orderBy: 'captured_at DESC');
    return rows.map(Observation.fromStorage).toList();
  }

  Future<List<Observation>> pendingObservations() async {
    final rows = await _database.query(
      'observations',
      where: 'sync_status IN (?, ?)',
      whereArgs: [SyncStatus.pending.name, SyncStatus.failed.name],
      orderBy: 'captured_at ASC',
    );
    return rows.map(Observation.fromStorage).toList();
  }

  Future<void> markSyncStatus(String id, SyncStatus status) async {
    await _database.update('observations', {'sync_status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => _database.close();
}
