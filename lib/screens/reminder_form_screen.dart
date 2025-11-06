import 'package:flutter/material.dart';
import 'package:itsupport_worklog/database/database_service.dart';
import 'package:itsupport_worklog/models/reminder_model.dart';
import 'package:itsupport_worklog/services/notification_service.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.initial});

  final Reminder? initial;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _dueCtrl;

  DateTime? _selectedDateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial?.taskTitle ?? '');
    _locationCtrl = TextEditingController(
      text: widget.initial?.locationDetail ?? '',
    );
    _sourceCtrl = TextEditingController(
      text: widget.initial?.instructionSource ?? '',
    );
    _dueCtrl = TextEditingController(text: widget.initial?.dueDate ?? '');

    // Try to parse existing due date to DateTime
    if (widget.initial?.dueDate != null) {
      final parsed = DateTime.tryParse(widget.initial!.dueDate);
      if (parsed != null) {
        _selectedDateTime = parsed.toLocal();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _sourceCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    // Pick date
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;

    // Pick time
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    // Combine
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    _selectedDateTime = combined;

    // ISO 8601 string for storage
    final iso = combined.toUtc().toIso8601String();
    _dueCtrl.text = iso;
    setState(() {});
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedDateTime == null) {
      // If user typed directly, try to parse
      final parsed = DateTime.tryParse(_dueCtrl.text.trim());
      if (parsed != null) {
        _selectedDateTime = parsed;
      }
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih tanggal dan waktu jatuh tempo.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final reminder = Reminder(
        id: widget.initial?.id,
        taskTitle: _titleCtrl.text.trim(),
        locationDetail: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        instructionSource: _sourceCtrl.text.trim().isEmpty
            ? null
            : _sourceCtrl.text.trim(),
        dueDate: _selectedDateTime!.toUtc().toIso8601String(),
        isCompleted: widget.initial?.isCompleted ?? false,
      );

      if (reminder.id == null) {
        // Simpan dan dapatkan ID baru untuk penjadwalan notifikasi.
        final newId = await DatabaseService().createReminder(reminder);
        final saved = reminder.copyWith(id: newId);
        await NotificationService().scheduleReminder(saved);
      } else {
        // Update existing reminder (requires updateReminder in DatabaseService)
        await DatabaseService().updateReminder(reminder);
        // Re-schedule notifikasi sesuai due date terbaru.
        await NotificationService().scheduleReminder(reminder);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminder.id == null
                ? 'Pengingat berhasil ditambahkan.'
                : 'Pengingat berhasil diperbarui.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan pengingat: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pengingat' : 'Tambah Pengingat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul Tugas',
                  hintText: 'Contoh: Perbaiki printer kantor',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Judul tugas wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Detail Lokasi',
                  hintText: 'Contoh: Lantai 2, Ruang Meeting',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sumber Instruksi',
                  hintText: 'Contoh: WhatsApp, Email, Lisan',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Jatuh Tempo (ISO 8601)',
                  hintText: 'Pilih tanggal & waktu',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.event),
                    tooltip: 'Pilih Tanggal & Waktu',
                    onPressed: _pickDateTime,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Tanggal & waktu jatuh tempo wajib diisi';
                  }
                  // Optional: validate ISO format
                  final parsed = DateTime.tryParse(v.trim());
                  if (parsed == null) {
                    return 'Format tanggal/waktu tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Perbarui' : 'Simpan'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
