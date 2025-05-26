// lib/models/worker.dart

class Worker {
  String name;
  String category;
  List<int> workDays; // 0=Monday, 6=Sunday
  double rating;

  Worker({
    required this.name,
    required this.category,
    required this.workDays,
    required this.rating,
  });

  // Calculate rating based on category
  static double getRatingForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'service':
        return 1.0;
      case 'cuisine':
        return 0.7;
      case 'clean':
        return 0.5;
      default:
        return 1.0;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'workDays': workDays,
    'rating': rating,
  };

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    name: json['name'] as String,
    category: json['category'] as String,
    workDays: List<int>.from(json['workDays'] ?? []),
    rating: (json['rating'] as num?)?.toDouble() ??
        getRatingForCategory(json['category'] as String),
  );
}