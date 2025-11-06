// main.dart: entry point aplikasi.
// Tambahan: inisialisasi sqflite_common_ffi untuk desktop (Windows/Linux/macOS)
// agar API sqflite tetap bisa dipakai.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:itsupport_worklog/database/database_service.dart';
import 'package:itsupport_worklog/screens/it_log_home_screen.dart';
import 'package:itsupport_worklog/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Pastikan binding Flutter siap sebelum inisialisasi plugin/FFI.
  WidgetsFlutterBinding.ensureInitialized();

  // Aktifkan backend SQLite FFI untuk desktop agar sqflite bekerja.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      // Inisialisasi notifikasi lokal (aman untuk mobile & desktop, web di-skip)
      await NotificationService().init();
      await DatabaseService().initDatabase();
      setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IT Support Log',
      // Set dark mode with teal/blue accentf
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          // Gunakan withOpacity agar kompatibel lintas versi Flutter.
          fillColor: Colors.black.withOpacity(0.06),
          border: const OutlineInputBorder(),
        ),
        // Gunakan CardThemeData agar kompatibel dengan versi Flutter SDK yang Anda gunakan
        cardTheme: const CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF2A2A2A)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Failed to initialize database:\n\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const ItLogHomeScreen();
  }
}
