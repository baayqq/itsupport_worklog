// ReminderScreen: daftar reminder dengan kategori.
// Penambahan: dua tombol AppBar untuk Backup dan Restore (menggunakan BackupService).
// Responsif: aksi diringkas dalam IconButton agar tetap nyaman di layar kecil.

import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import 'package:itsupport_worklog/database/database_service.dart';
import 'package:itsupport_worklog/models/reminder_model.dart';
import 'package:itsupport_worklog/screens/reminder_form_screen.dart';
import 'package:itsupport_worklog/services/notification_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final BackupService _backupService = BackupService();
  late Future<List<Reminder>> _futureReminders;

  @override
  void initState() {
    super.initState();
    _futureReminders = _loadReminders();
  }

  Future<List<Reminder>> _loadReminders() async {
    try {
      return await DatabaseService().readAllReminders();
    } catch (e) {
      throw Exception('Gagal memuat pengingat: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReminders = _loadReminders();
    });
  }

  Future<void> _toggleComplete(Reminder reminder, bool value) async {
    try {
      await DatabaseService().updateReminderStatus(
        id: reminder.id!,
        isCompleted: value,
      );
      // Kelola notifikasi: batalkan jika selesai, jadwalkan ulang jika diaktifkan kembali.
      if (value == true) {
        await NotificationService().cancelReminder(reminder.id!);
      } else {
        await NotificationService().scheduleReminder(reminder);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Tugas ditandai selesai.' : 'Tugas ditandai aktif.',
          ),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status: $e')));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildItem(Reminder r) {
    // Format due date sederhana
    String dueLabel = r.dueDate;
    final parsed = DateTime.tryParse(r.dueDate);
    if (parsed != null) {
      final local = parsed.toLocal();
      dueLabel =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.taskTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (r.locationDetail != null && r.locationDetail!.isNotEmpty)
                    Text(
                      r.locationDetail!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('Due: $dueLabel', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                Checkbox(
                  value: r.isCompleted,
                  onChanged: r.id == null
                      ? null
                      : (val) {
                          if (val == null) return;
                          _toggleComplete(r, val);
                        },
                  tristate: false,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ReminderFormScreen(initial: r),
                      ),
                    );
                    if (mounted && (result ?? false)) {
                      _refresh();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Hapus',
                  onPressed: r.id == null
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Pengingat'),
                              content: Text(
                                'Apakah Anda yakin ingin menghapus "${r.taskTitle}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await DatabaseService().deleteReminder(r.id!);
                              await NotificationService().cancelReminder(r.id!);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pengingat dihapus.'),
                                ),
                              );
                              _refresh();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menghapus: $e')),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          // Ubah "Backup" menjadi "Download ke Downloads"
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              await _backupService.saveToDownloads(context);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Restore Options',
            icon: const Icon(Icons.file_open),
            onSelected: (value) async {
              if (value == 'overwrite') {
                await _backupService.importDatabase(context);
              } else if (value == 'merge') {
                await _backupService.importDatabaseMerge(context);
              }
              if (!mounted) return;
              await _refresh();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'overwrite',
                child: Text('Restore (Replace Database)'),
              ),
              PopupMenuItem(
                value: 'merge',
                child: Text('Restore (Merge/Add Data)'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Reminder>>(
          future: _futureReminders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Terjadi kesalahan saat memuat pengingat:\n\n${snapshot.error}\n\nCatatan: SQLite tidak didukung di Flutter Web. Jalankan di Android/iOS/Desktop untuk fungsi penuh.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            final reminders = snapshot.data ?? [];
            if (reminders.isEmpty) {
              return const Center(
                child: Text(
                  'Belum ada pengingat. Tambahkan dari modul lainnya.',
                ),
              );
            }
            final active = reminders.where((r) => !r.isCompleted).toList();
            final completed = reminders.where((r) => r.isCompleted).toList();

            final List<Widget> children = [];
            if (active.isNotEmpty) {
              children.add(_buildSectionHeader('Upcoming/Active Tasks'));
              children.addAll(active.map(_buildItem));
            }
            if (completed.isNotEmpty) {
              children.add(_buildSectionHeader('Completed Tasks'));
              children.addAll(completed.map(_buildItem));
            }

            if (children.isEmpty) {
              return const Center(
                child: Text('Tidak ada pengingat untuk ditampilkan.'),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ReminderFormScreen()),
          );
          if (mounted && (result ?? false)) {
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
