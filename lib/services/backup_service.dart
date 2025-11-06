// BackupService: menangani ekspor/impor database SQLite aplikasi.
// Fitur:
// - saveToDownloads: simpan file DB ke folder Downloads (Android Scoped Storage).
// - exportDatabase: share file DB via share sheet (opsional, tetap disediakan).
// - importDatabase: memilih file .db lalu menimpa DB aplikasi.
// Catatan: Menggunakan sqflite, file_saver, file_picker, share_plus, path_provider.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:itsupport_worklog/database/database_service.dart';

class BackupService {
  // Nama file database yang digunakan aplikasi.
  static const String _dbFileName = 'it_support_log.db';

  // Simpan DB ke Downloads menggunakan MediaStore (aman untuk Android 10+).
  Future<void> saveToDownloads(BuildContext context) async {
    try {
      final existingPath = await _findExistingDbPath();
      if (existingPath == null) {
        _showSnackBar(context, 'Database tidak ditemukan pada lokasi standar.');
        return;
      }
      final bytes = await File(existingPath).readAsBytes();

      await FileSaver.instance.saveFile(
        name: _dbFileName, // sudah termasuk .db
        bytes: bytes,
        mimeType: MimeType.other,
      );

      _showSnackBar(context, 'Backup disimpan ke folder Downloads.');
    } catch (e) {
      _showSnackBar(context, 'Gagal menyimpan ke Downloads: $e');
    }
  }

  // Ekspor database: membuka share sheet agar file bisa dikirim (email/drive/wa).
  Future<void> exportDatabase(BuildContext context) async {
    try {
      final existingPath = await _findExistingDbPath();
      if (existingPath == null) {
        _showSnackBar(context, 'Database tidak ditemukan pada lokasi standar.');
        return;
      }
      await Share.shareXFiles([
        XFile(existingPath),
      ], text: 'Backup database aplikasi ($_dbFileName)');
      _showSnackBar(context, 'Backup dibagikan.');
    } catch (e) {
      _showSnackBar(context, 'Gagal backup: $e');
    }
  }

  // Impor database: pilih file .db, tutup koneksi DB aplikasi, lalu timpa DB.
  Future<void> importDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih file backup (.db)',
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (result == null || result.files.isEmpty) {
        _showSnackBar(context, 'Impor dibatalkan.');
        return;
      }
      final pickedPath = result.files.single.path;
      if (pickedPath == null) {
        _showSnackBar(context, 'File tidak valid.');
        return;
      }
      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        _showSnackBar(context, 'File backup tidak ditemukan.');
        return;
      }

      await DatabaseService().closeDatabase();

      final docsDir = await getApplicationDocumentsDirectory();
      final appDbPath = p.join(docsDir.path, _dbFileName);
      await docsDir.create(recursive: true);
      await sourceFile.copy(appDbPath);

      _showSnackBar(
        context,
        'Restore berhasil. Muat ulang data untuk melihat perubahan.',
      );
    } catch (e) {
      _showSnackBar(context, 'Gagal restore: $e');
    }
  }

  // Impor database secara MERGE (tidak menimpa file DB utama).
  // Data dari file backup akan ditambahkan ke database aplikasi jika belum ada.
  Future<void> importDatabaseMerge(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih file backup (.db) untuk merge',
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (result == null || result.files.isEmpty) {
        _showSnackBar(context, 'Merge dibatalkan.');
        return;
      }
      final pickedPath = result.files.single.path;
      if (pickedPath == null) {
        _showSnackBar(context, 'File tidak valid.');
        return;
      }
      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        _showSnackBar(context, 'File backup tidak ditemukan.');
        return;
      }

      // Pastikan DB aplikasi sudah siap.
      await DatabaseService().initDatabase();
      final resultCounts = await DatabaseService().mergeFromExternalDb(
        pickedPath,
      );

      _showSnackBar(
        context,
        'Merge selesai: +${resultCounts['logs']} log, +${resultCounts['reminders']} reminder.',
      );
    } catch (e) {
      _showSnackBar(context, 'Gagal merge: $e');
    }
  }

  // Cari file DB di dua kemungkinan lokasi (baru & lama)
  Future<String?> _findExistingDbPath() async {
    try {
      final dbDir = await getDatabasesPath();
      final path1 = '$dbDir/$_dbFileName';
      if (await File(path1).exists()) return path1;

      final docsDir = await getApplicationDocumentsDirectory();
      final path2 = p.join(docsDir.path, _dbFileName);
      if (await File(path2).exists()) return path2;

      return null;
    } catch (_) {
      return null;
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
