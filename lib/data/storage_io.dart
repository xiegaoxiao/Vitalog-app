import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalStore {
  Database? _database;
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    final dir = await getApplicationSupportDirectory();
    _database = await openDatabase(
      '${dir.path}/vitalog.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE state (id INTEGER PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT NOT NULL)',
        );
      },
    );
    return _database!;
  }

  Future<String?> load() async {
    final rows = await (await database).query('state', where: 'id = 1');
    return rows.isEmpty ? null : rows.first['data'] as String;
  }

  Future<void> save(String value) async {
    await (await database).transaction((txn) async {
      final old = await txn.query('state', where: 'id = 1');
      if (old.isNotEmpty) {
        await txn.insert('history', {'data': old.first['data']});
      }
      await txn.insert('state', {
        'id': 1,
        'data': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.execute(
        'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT 5)',
      );
    });
  }

  Future<String?> previous() async {
    final rows = await (await database).query(
      'history',
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['data'] as String;
  }
}
