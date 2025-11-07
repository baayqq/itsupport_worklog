import 'package:flutter/material.dart';
import 'package:itsupport_worklog/database/database_service.dart';
import 'package:itsupport_worklog/models/it_log_model.dart';

class ItLogFormScreen extends StatefulWidget {
  final ItLog? initialLog; // null => create mode, non-null => edit mode
  const ItLogFormScreen({super.key, this.initialLog});

  @override
  State<ItLogFormScreen> createState() => _ItLogFormScreenState();
}

class _ItLogFormScreenState extends State<ItLogFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _solutionController;

  // Dropdown selections
  String? _selectedCategory;
  String? _selectedStatus;

  // Timestamp (epoch ms)
  late int _timestampMs;

  bool _saving = false;

  static const _categories = <String>[
    'Network', 'Hardware', 'Software', 'User Support', 'Other'
  ];
  static const _statuses = <String>[
    'Open', 'In Progress', 'Pending', 'Resolved', 'Closed'
  ];

  bool get _isEdit => widget.initialLog != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialLog?.title ?? '');
    _descriptionController = TextEditingController(text: widget.initialLog?.description ?? '');
    _solutionController = TextEditingController(text: widget.initialLog?.solutionSteps ?? '');
    _selectedCategory = widget.initialLog?.category;
    _selectedStatus = widget.initialLog?.status ?? 'Pending';
    _timestampMs = widget.initialLog?.timestamp ?? DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _solutionController.dispose();
    super.dispose();
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _pickDate() async {
    final current = DateTime.fromMillisecondsSinceEpoch(_timestampMs);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      // Keep the current time component
      final updated = DateTime(date.year, date.month, date.day, current.hour, current.minute);
      setState(() => _timestampMs = updated.millisecondsSinceEpoch);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final log = ItLog(
        id: widget.initialLog?.id,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        solutionSteps: _solutionController.text.trim().isEmpty ? null : _solutionController.text.trim(),
        timestamp: _timestampMs,
        status: _selectedStatus,
      );

      if (_isEdit) {
        await DatabaseService().updateLog(log);
      } else {
        await DatabaseService().createLog(log);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Catatan diperbarui.' : 'Catatan ditambahkan.')),
        );
        Navigator.of(context).pop(true); // indicate success to caller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsif: batasi lebar konten agar nyaman di tablet/desktop
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Catatan' : 'Tambah Catatan'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'Simpan',
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth >= 900
              ? 700.0
              : constraints.maxWidth >= 600
                  ? 560.0
                  : constraints.maxWidth; // di ponsel, gunakan penuh

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul',
                        hintText: 'Contoh: Internet kantor lambat',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Judul wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                    const SizedBox(height: 12),
                    // Deskripsi dibuat nyaman dibaca: tinggi menengah
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Masalah',
                        hintText: 'Jelaskan kendala yang terjadi...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Langkah solusi diperbesar sesuai permintaan
                    TextFormField(
                      controller: _solutionController,
                      minLines: 6,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Langkah Solusi',
                        hintText: 'Catat langkah-langkah yang dilakukan...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Langkah solusi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map((s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Waktu',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_formatTimestamp(_timestampMs))),
                          TextButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Pilih Tanggal'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label:
                            Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}