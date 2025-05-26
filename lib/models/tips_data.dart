// lib/models/tips_data.dart

class TipsData {
  double total;
  List<String> workers;

  TipsData({
    required this.total,
    required this.workers,
  });

  Map<String, dynamic> toJson() => {
    'total': total,
    'workers': workers,
  };

  factory TipsData.fromJson(Map<String, dynamic> json) => TipsData(
    total: (json['total'] as num?)?.toDouble() ?? 0.0,
    workers: List<String>.from(json['workers'] ?? []),
  );
}