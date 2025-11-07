// notification_service.dart: layanan untuk notifikasi lokal terjadwal.
// Tujuan: menjadwalkan notifikasi saat Reminder dibuat/diubah,
// dan membatalkan notifikasi saat Reminder dihapus atau ditandai selesai.
//
// Catatan:
// - Menggunakan flutter_local_notifications dan timezone untuk penjadwalan akurat.
// - Web tidak didukung oleh flutter_local_notifications; aman untuk di-skip.
// - Desktop dan mobile didukung, namun perizinan notifikasi perlu diproses.
//
// Penggunaan singkat:
//   await NotificationService().init();
//   await NotificationService().scheduleReminder(reminder);
//   await NotificationService().cancelReminder(reminder.id!);
//
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:itsupport_worklog/models/reminder_model.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inisialisasi plugin dan timezone. Aman dipanggil berkali-kali.
  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      // Notifikasi lokal tidak didukung di Flutter Web oleh plugin ini.
      _initialized = true;
      return;
    }

    // Inisialisasi timezone (wajib untuk zonedSchedule)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_deviceTimeZoneName()));

    // Konfigurasi initialize settings untuk Android/iOS/macOS
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(initSettings);
    // Catatan: beberapa platform (iOS/macOS) membutuhkan izin notifikasi.
    // Untuk menjaga kompatibilitas lintas versi plugin, pemintaan izin eksplisit
    // dihapus di sini. Anda bisa menambahkan UI terpisah untuk meminta izin,
    // atau mengandalkan pengaturan sistem pengguna.
    // Android 13+ (API 33) perlu izin runtime. Plugin tidak punya API langsung,
    // jadi pastikan pengguna mengizinkan notifikasi dari sistem (bisa diarahkan via UI terpisah jika diperlukan).

    _initialized = true;
  }

  /// Menentukan timezone perangkat. Fallback ke 'Asia/Jakarta' bila tidak diketahui.
  String _deviceTimeZoneName() {
    // Flutter tidak menyediakan API langsung nama timezone.
    // Menggunakan fallback yang aman untuk pengguna Indonesia.
    // Anda bisa sesuaikan ke lokasi lain bila target pengguna berbeda.
    return 'Asia/Jakarta';
  }

  /// Menjadwalkan notifikasi untuk sebuah reminder.
  /// - Menggunakan reminder.id sebagai notificationId agar bisa dibatalkan spesifik.
  /// - Melewatkan penjadwalan bila dueDate sudah lewat.
  Future<void> scheduleReminder(Reminder reminder) async {
    if (!_initialized) {
      await init();
    }
    if (kIsWeb) return;
    if (reminder.id == null)
      return; // perlu ID untuk notifikasi yang dapat dibatalkan

    final DateTime? parsed = DateTime.tryParse(reminder.dueDate);
    if (parsed == null) return;
    final DateTime localTime = parsed.toLocal();
    if (localTime.isBefore(DateTime.now())) {
      // Jangan jadwalkan notifikasi di masa lalu
      return;
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(localTime, tz.local);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'Notifikasi pengingat tugas IT Support',
          importance: Importance.high,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      reminder.id!,
      'Pengingat: ${reminder.taskTitle}',
      _buildBody(reminder),
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reminder:${reminder.id}',
      matchDateTimeComponents: null,
    );
  }

  /// Membatalkan notifikasi untuk reminder ID tertentu.
  Future<void> cancelReminder(int id) async {
    if (!_initialized) {
      await init();
    }
    if (kIsWeb) return;
    try {
      // Upaya normal untuk membatalkan notifikasi berdasarkan ID.
      await _plugin.cancel(id);
    } catch (e) {
      // Beberapa versi plugin flutter_local_notifications pada Android
      // dapat melempar PlatformException("Missing type parameter") saat
      // membaca cache notifikasi lama (terbuat dari versi plugin berbeda).
      // Agar UI tidak gagal saat centang/hapus, kita tangani secara aman.
      try {
        // Coba batalkan melalui implementasi spesifik Android.
        final android = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.cancel(id);
      } catch (_) {
        // Terakhir, coba cancelAll sebagai fallback.
        // Jika tetap gagal, kita biarkan saja agar aksi UI tetap lanjut.
        try {
          await _plugin.cancelAll();
        } catch (_) {}
      }
    }
  }

  String _buildBody(Reminder r) {
    final buf = StringBuffer();
    if (r.locationDetail != null && r.locationDetail!.isNotEmpty) {
      buf.write('Lokasi: ${r.locationDetail}!\n');
    }
    if (r.instructionSource != null && r.instructionSource!.isNotEmpty) {
      buf.write('Sumber: ${r.instructionSource}!\n');
    }
    final parsed = DateTime.tryParse(r.dueDate)?.toLocal();
    if (parsed != null) {
      buf.write(
        'Jatuh Tempo: ${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ',
      );
      buf.write(
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}',
      );
    }
    return buf.toString().trim().isEmpty
        ? 'Jangan lupa menyelesaikan tugas Anda.'
        : buf.toString();
  }
}
