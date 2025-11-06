class ItLog {
  final int? id; // Primary Key (auto-increment)
  final String title; // Judul Masalah
  final String? category; // Kategori Masalah
  final String? description; // Detail kendala
  final String? solutionSteps; // Langkah solusi yang sudah dilakukan
  final int timestamp; // Waktu kejadian (epoch milliseconds)
  final String? status; // Status, e.g., 'Selesai', 'Pending'

  ItLog({
    this.id,
    required this.title,
    this.category,
    this.description,
    this.solutionSteps,
    required this.timestamp,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'solution_steps': solutionSteps,
      'timestamp': timestamp,
      'status': status,
    };
  }

  factory ItLog.fromMap(Map<String, dynamic> map) {
    return ItLog(
      id: map['id'] is int ? map['id'] as int : (map['id'] == null ? null : int.tryParse(map['id'].toString())),
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString(),
      description: map['description']?.toString(),
      solutionSteps: map['solution_steps']?.toString(),
      timestamp: map['timestamp'] is int
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '') ?? 0,
      status: map['status']?.toString(),
    );
  }
}