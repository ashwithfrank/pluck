import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Persists the queue + history so nothing is lost when the app is killed.
class Db {
  Db._();
  static final Db I = Db._();

  Database? _db;

  Future<Database> get _d async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'pluck.db'),
        version: 1,
        onCreate: (db, v) => db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            label TEXT NOT NULL,
            options TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            thumbnail TEXT,
            uploader TEXT,
            duration REAL,
            is_audio INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            progress REAL NOT NULL DEFAULT 0,
            uri TEXT,
            name TEXT,
            size INTEGER,
            mime TEXT,
            error TEXT
          )
        '''),
      );

  Future<List<DownloadItem>> all() async {
    final rows = await (await _d).query('downloads', orderBy: 'created_at DESC');
    return rows.map(DownloadItem.fromRow).toList();
  }

  Future<void> upsert(DownloadItem i) async {
    await (await _d).insert('downloads', i.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String id) async {
    await (await _d).delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearFinished() async {
    await (await _d).delete('downloads', where: "status = 'done'");
  }
}
