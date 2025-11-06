import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IT Support Log'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Selamat datang di IT Support Log.\n\nDatabase sudah terinisialisasi. Anda bisa menambahkan layar daftar log dan form input selanjutnya.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}