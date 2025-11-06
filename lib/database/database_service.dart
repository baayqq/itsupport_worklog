import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:itsupport_worklog/models/it_log_model.dart';
import 'package:itsupport_worklog/models/reminder_model.dart';

// DatabaseService: layanan SQLite aplikasi.
// Penambahan: metode closeDatabase() untuk menutup koneksi DB sebelum restore.
// Metode lain (createReminder/updateReminder/dll) tetap seperti sebelumnya.

import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  static const String dbName = 'it_support_log.db';
  static const int dbVersion = 3;

  static const String tableItLog = 'it_log_table';
  static const String tableReminder = 'reminder_table';

  Database? _db;
  Database? get database => _db;

  /// Initialize and open the SQLite database and ensure the main table exists.
  Future<Database?> initDatabase() async {
    // Skip initialization on web since sqflite isn't supported there by default.
    if (kIsWeb) {
      // You can add sqflite_common_ffi_web in the future for web support.
      _db = null;
      return _db;
    }

    // Determine a valid path for the database file.
    Directory dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, dbName);

    _db = await openDatabase(
      dbPath,
      version: dbVersion,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Add new columns for v2 schema
          await db.execute("ALTER TABLE $tableItLog ADD COLUMN category TEXT;");
          await db.execute(
            "ALTER TABLE $tableItLog ADD COLUMN solution_steps TEXT;",
          );
          await db.execute(
            "ALTER TABLE $tableItLog ADD COLUMN timestamp INTEGER;",
          );
          await db.execute(
            "UPDATE $tableItLog SET timestamp = created_at WHERE timestamp IS NULL;",
          );
          // Keep existing status column; originally existed in v1.
        }
        if (oldVersion < 3) {
          // Create reminder table for v3
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableReminder (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_title TEXT NOT NULL,
              location_detail TEXT,
              instruction_source TEXT,
              due_date TEXT NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0
            );
          ''');
        }
      },
    );

    return _db;
  }

  Future<void> _createTables(Database db) async {
    // Main IT Support Log table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableItLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT,
        description TEXT,
        solution_steps TEXT,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'Pending'
      );
    ''');
    // Reminder table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReminder (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_title TEXT NOT NULL,
        location_detail TEXT,
        instruction_source TEXT,
        due_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  // Helpers
  String _normalizeStatus(String s) {
    switch (s.toLowerCase()) {
      case 'selesai':
        return 'Resolved';
      case 'pending':
        return 'Pending';
      case 'open':
        return 'Open';
      case 'in progress':
      case 'in_progress':
      case 'in-progress':
        return 'In Progress';
      case 'closed':
        return 'Closed';
      default:
        return s;
    }
  }

  Future<int> createLog(ItLog log) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    final data = log.toMap();
    data.remove('id');
    return await db.insert(
      tableItLog,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ItLog>> readAllLogs({String? status, String? category}) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (status != null && status.trim().isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(_normalizeStatus(status));
    }
    if (category != null && category.trim().isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category.trim());
    }
    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final List<Map<String, dynamic>> maps = await db.query(
      tableItLog,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ItLog.fromMap(m)).toList();
  }

  Future<List<ItLog>> searchLogs(
    String query, {
    String? status,
    String? category,
  }) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    final q = query.trim();
    if (q.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR description LIKE ?)');
      whereArgs.add('%$q%');
      whereArgs.add('%$q%');
    }
    if (status != null && status.trim().isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(_normalizeStatus(status));
    }
    if (category != null && category.trim().isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category.trim());
    }
    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final maps = await db.query(
      tableItLog,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ItLog.fromMap(m)).toList();
  }

  Future<int> updateLog(ItLog log) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    if (log.id == null) {
      throw ArgumentError('updateLog requires a log with non-null id');
    }
    final data = log.toMap();
    data.remove('id');
    return await db.update(
      tableItLog,
      data,
      where: 'id = ?',
      whereArgs: [log.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteLog(int id) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return await db.delete(tableItLog, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createReminder(Reminder reminder) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    final data = reminder.toMap();
    data.remove('id');
    return await db.insert(
      tableReminder,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Reminder>> readAllReminders({bool? isCompleted}) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    String? where;
    List<Object?>? whereArgs;
    if (isCompleted != null) {
      where = 'is_completed = ?';
      whereArgs = [isCompleted ? 1 : 0];
    }
    final maps = await db.query(
      tableReminder,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'due_date ASC',
    );
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<int> updateReminderStatus({
    required int id,
    required bool isCompleted,
  }) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return await db.update(
      tableReminder,
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return await db.delete(tableReminder, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = _db ?? await initDatabase();
    if (db == null) {
      throw StateError('Database not initialized');
    }
    if (reminder.id == null) {
      throw ArgumentError(
        'updateReminder requires a reminder with non-null id',
      );
    }
    final data = reminder.toMap();
    data.remove('id');
    return await db.update(
      tableReminder,
      data,
      where: 'id = ?',
      whereArgs: [reminder.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Tambahkan method ini untuk menutup koneksi DB dengan aman.
  Future<void> closeDatabase() async {
    try {
      final db = _db;
      if (db != null && db.isOpen) {
        await db.close();
      }
      // Set internal ref ke null agar bisa re-init saat dipakai lagi.
      _db = null;
    } catch (_) {
      // Diamkan agar tidak mengganggu flow restore.
    }
  }

  /// Merge data dari file database eksternal (mis. hasil backup di desktop)
  /// ke database aplikasi TANPA menimpa file database utama.
  ///
  /// Aturan merge sederhana agar junior-friendly:
  /// - ItLog: dianggap duplikat jika ada baris dengan title dan timestamp yang sama.
  /// - Reminder: dianggap duplikat jika ada baris dengan task_title dan due_date yang sama.
  /// - Baris duplikat di-skip, baris baru di-insert (id dihapus agar autoincrement).
  ///
  /// Mengembalikan jumlah baris yang berhasil ditambahkan per tabel.
  Future<Map<String, int>> mergeFromExternalDb(String externalDbPath) async {
    final mainDb = _db ?? await initDatabase();
    if (mainDb == null) {
      throw StateError('Database not initialized');
    }

    // Buka koneksi ke file database eksternal.
    final externalDb = await openDatabase(externalDbPath);
    int addedLogs = 0;
    int addedReminders = 0;
    try {
      // Ambil semua log dari DB eksternal.
      final externalLogs = await externalDb.query(tableItLog);
      for (final row in externalLogs) {
        final title = row['title'] as String?;
        final timestamp = row['timestamp'] as int?;
        if (title == null || timestamp == null) {
          continue; // lewati baris yang tidak lengkap
        }
        final exists = await mainDb.query(
          tableItLog,
          where: 'title = ? AND timestamp = ?',
          whereArgs: [title, timestamp],
          limit: 1,
        );
        if (exists.isEmpty) {
          final data = Map<String, dynamic>.from(row);
          data.remove('id');
          await mainDb.insert(
            tableItLog,
            data,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          addedLogs++;
        }
      }

      // Ambil semua reminder dari DB eksternal.
      final externalReminders = await externalDb.query(tableReminder);
      for (final row in externalReminders) {
        final taskTitle = row['task_title'] as String?;
        final dueDate = row['due_date'] as String?;
        if (taskTitle == null || dueDate == null) {
          continue;
        }
        final exists = await mainDb.query(
          tableReminder,
          where: 'task_title = ? AND due_date = ?',
          whereArgs: [taskTitle, dueDate],
          limit: 1,
        );
        if (exists.isEmpty) {
          final data = Map<String, dynamic>.from(row);
          data.remove('id');
          await mainDb.insert(
            tableReminder,
            data,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          addedReminders++;
        }
      }

      return {'logs': addedLogs, 'reminders': addedReminders};
    } finally {
      await externalDb.close();
    }
  }
}
