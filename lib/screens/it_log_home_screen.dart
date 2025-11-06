import 'package:flutter/material.dart';
import 'package:itsupport_worklog/database/database_service.dart';
import 'package:itsupport_worklog/models/it_log_model.dart';
import 'package:itsupport_worklog/screens/it_log_form_screen.dart';
import 'package:itsupport_worklog/screens/reminder_screen.dart';

class ItLogHomeScreen extends StatefulWidget {
  const ItLogHomeScreen({super.key});

  @override
  State<ItLogHomeScreen> createState() => _ItLogHomeScreenState();
}

class _ItLogHomeScreenState extends State<ItLogHomeScreen> {
  late Future<List<ItLog>> _futureLogs;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterStatus; // e.g., 'Pending', 'Resolved' or 'Selesai'
  String? _filterCategory; // e.g., 'Network', 'Hardware', ...

  static const _categories = <String>[
    'Network', 'Hardware', 'Software', 'User Support', 'Other'
  ];
  // Removed unused _statuses list

  @override
  void initState() {
    super.initState();
    _futureLogs = _fetchLogs();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _futureLogs = _fetchLogs();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ItLog>> _fetchLogs() async {
    try {
      if (_searchQuery.isNotEmpty) {
        return await DatabaseService().searchLogs(
          _searchQuery,
          status: _filterStatus,
          category: _filterCategory,
        );
      }
      return await DatabaseService().readAllLogs(
        status: _filterStatus,
        category: _filterCategory,
      );
    } catch (e) {
      throw Exception('Gagal memuat data: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureLogs = _fetchLogs();
    });
  }

  Future<void> _onAddPressed() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ItLogFormScreen()),
    );
    if (!mounted) return;
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _onEdit(ItLog log) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItLogFormScreen(initialLog: log)),
    );
    if (!mounted) return;
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _onDelete(ItLog log) async {
    if (log.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID catatan tidak ditemukan, tidak dapat dihapus.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: Text('Apakah Anda yakin ingin menghapus "${log.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      try {
        await DatabaseService().deleteLog(log.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan dihapus.')),
        );
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  void _onFilterSelected(String value) {
    if (value == 'clear_filters') {
      setState(() {
        _filterStatus = null;
        _filterCategory = null;
        _futureLogs = _fetchLogs();
      });
      return;
    }
    if (value.startsWith('status:')) {
      final statusValue = value.substring('status:'.length);
      setState(() {
        _filterStatus = statusValue; // DatabaseService normalizes 'Selesai' -> 'Resolved'
        _futureLogs = _fetchLogs();
      });
      return;
    }
    if (value.startsWith('category:')) {
      final catValue = value.substring('category:'.length);
      setState(() {
        _filterCategory = catValue;
        _futureLogs = _fetchLogs();
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar IT Work Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Pengingat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReminderScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: _onFilterSelected,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'status:Pending', child: Text('Status: Pending')),
              const PopupMenuItem(value: 'status:Resolved', child: Text('Status: Selesai')),
              const PopupMenuDivider(),
              ..._categories.map((c) => PopupMenuItem(
                    value: 'category:$c',
                    child: Text('Kategori: $c'),
                  )),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear_filters', child: Text('Hapus Filter')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul atau deskripsi...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
                filled: true,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ItLog>>(
          future: _futureLogs,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Terjadi kesalahan saat memuat data:\n\n${snapshot.error}\n\nCatatan: SQLite tidak didukung di Flutter Web. Jalankan di Android/iOS/Desktop untuk fungsi penuh.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return const Center(
                child: Text('Belum ada catatan. Tambahkan menggunakan tombol +.'),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: InkWell(
                    onTap: () => _onEdit(log),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusDot(status: log.status),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.category ?? '-',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _onEdit(log);
                              } else if (value == 'delete') {
                                _onDelete(log);
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Hapus')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        child: const Icon(Icons.add),
        tooltip: 'Tambah Catatan',
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String? status;
  const _StatusDot({required this.status});

  Color _colorForStatus(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'resolved':
      case 'selesai':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}