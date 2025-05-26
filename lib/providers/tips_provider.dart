// lib/providers/tips_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/worker.dart';
import '../models/tips_data.dart';

class TipsProvider extends ChangeNotifier {
  Map<String, Worker> _workers = {};
  Map<String, TipsData> _tipsData = {};

  Map<String, Worker> get workers => _workers;
  Map<String, TipsData> get tipsData => _tipsData;

  TipsProvider() {
    loadData();
  }

  // Add or update worker
  void addOrUpdateWorker(Worker worker) {
    _workers[worker.name] = worker;
    saveData();
    notifyListeners();
  }

  // Remove worker
  void removeWorker(String name) {
    _workers.remove(name);

    // Remove worker from all tips data
    _tipsData.forEach((date, data) {
      data.workers.remove(name);
    });

    // Remove empty entries
    _tipsData.removeWhere((date, data) =>
    data.workers.isEmpty && data.total == 0.0);

    saveData();
    notifyListeners();
  }

  // Get workers for a specific day of week
  List<Worker> getWorkersForDay(int dayOfWeek) {
    return _workers.values
        .where((worker) => worker.workDays.contains(dayOfWeek))
        .toList();
  }

  // Save tips for a date
  void saveTips(String dateStr, double amount) {
    if (_tipsData.containsKey(dateStr)) {
      _tipsData[dateStr]!.total = amount;
    } else {
      // Get default workers for this day
      DateTime date = DateTime.parse(dateStr);
      int dayOfWeek = date.weekday - 1; // Convert to 0-based
      List<String> defaultWorkers = getWorkersForDay(dayOfWeek)
          .map((w) => w.name)
          .toList();

      _tipsData[dateStr] = TipsData(
        total: amount,
        workers: defaultWorkers,
      );
    }

    // Remove if empty
    if (amount == 0.0 && _tipsData[dateStr]!.workers.isEmpty) {
      _tipsData.remove(dateStr);
    }

    saveData();
    notifyListeners();
  }

  // Add worker to specific date
  void addWorkerToDate(String dateStr, String workerName) {
    if (!_tipsData.containsKey(dateStr)) {
      _tipsData[dateStr] = TipsData(total: 0.0, workers: []);
    }

    if (!_tipsData[dateStr]!.workers.contains(workerName)) {
      _tipsData[dateStr]!.workers.add(workerName);
      _tipsData[dateStr]!.workers.sort();
      saveData();
      notifyListeners();
    }
  }

  // Remove worker from specific date
  void removeWorkerFromDate(String dateStr, String workerName) {
    if (_tipsData.containsKey(dateStr)) {
      _tipsData[dateStr]!.workers.remove(workerName);

      // Remove entry if empty
      if (_tipsData[dateStr]!.workers.isEmpty &&
          _tipsData[dateStr]!.total == 0.0) {
        _tipsData.remove(dateStr);
      }

      saveData();
      notifyListeners();
    }
  }

  // Calculate tip distribution for a date
  Map<String, double> calculateDistribution(String dateStr) {
    Map<String, double> distribution = {};

    if (!_tipsData.containsKey(dateStr)) return distribution;

    TipsData data = _tipsData[dateStr]!;
    if (data.total <= 0 || data.workers.isEmpty) return distribution;

    // Calculate total rating points
    double totalRatingPoints = 0.0;
    Map<String, double> workerRatings = {};

    for (String workerName in data.workers) {
      if (_workers.containsKey(workerName)) {
        double rating = _workers[workerName]!.rating;
        workerRatings[workerName] = rating;
        totalRatingPoints += rating;
      }
    }

    // Calculate individual shares
    if (totalRatingPoints > 0) {
      workerRatings.forEach((name, rating) {
        distribution[name] = (rating / totalRatingPoints) * data.total;
      });
    }

    return distribution;
  }

  // Get monthly report data
  Map<String, dynamic> getMonthlyReport(int year, int month, bool isWeighted) {
    Map<String, Map<String, dynamic>> workerTotals = {};
    double totalMonthlyTips = 0.0;
    int daysWithTips = 0;

    _tipsData.forEach((dateStr, data) {
      DateTime date = DateTime.parse(dateStr);
      if (date.year == year && date.month == month && data.total > 0) {
        totalMonthlyTips += data.total;
        daysWithTips++;

        if (isWeighted) {
          // Calculate weighted distribution for each day
          Map<String, double> dayDistribution = calculateDistribution(dateStr);
          dayDistribution.forEach((name, amount) {
            workerTotals.putIfAbsent(name, () => {'total': 0.0, 'days': 0});
            workerTotals[name]!['total'] += amount;
            workerTotals[name]!['days']++;
          });
        } else {
          // Days-based distribution
          for (String workerName in data.workers) {
            if (_workers.containsKey(workerName)) {
              workerTotals.putIfAbsent(workerName, () => {
                'total': 0.0,
                'days': 0,
                'rating': _workers[workerName]!.rating
              });
              workerTotals[workerName]!['days']++;
            }
          }
        }
      }
    });

    // For days-based, calculate final amounts
    if (!isWeighted && workerTotals.isNotEmpty) {
      double totalWeightedDays = 0.0;
      workerTotals.forEach((name, stats) {
        totalWeightedDays += stats['days'] * stats['rating'];
      });

      if (totalWeightedDays > 0) {
        workerTotals.forEach((name, stats) {
          double weightedDays = stats['days'] * stats['rating'];
          stats['total'] = (weightedDays / totalWeightedDays) * totalMonthlyTips;
        });
      }
    }

    return {
      'totalTips': totalMonthlyTips,
      'daysWithTips': daysWithTips,
      'workerTotals': workerTotals,
    };
  }

  // Reset month tips
  void resetMonthTips(int year, int month) {
    List<String> keysToDelete = [];

    _tipsData.forEach((dateStr, data) {
      DateTime date = DateTime.parse(dateStr);
      if (date.year == year && date.month == month) {
        keysToDelete.add(dateStr);
      }
    });

    for (String key in keysToDelete) {
      _tipsData.remove(key);
    }

    saveData();
    notifyListeners();
  }

  // Save data to SharedPreferences
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> dataToSave = {
      'workers': _workers.map((key, value) => MapEntry(key, value.toJson())),
      'tips_data': _tipsData.map((key, value) => MapEntry(key, value.toJson())),
    };

    await prefs.setString('tips_manager_data', jsonEncode(dataToSave));
  }

  // Load data from SharedPreferences
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? dataStr = prefs.getString('tips_manager_data');

    if (dataStr != null) {
      try {
        Map<String, dynamic> data = jsonDecode(dataStr);

        // Load workers
        if (data['workers'] != null) {
          Map<String, dynamic> workersData = data['workers'];
          _workers = workersData.map((key, value) =>
              MapEntry(key, Worker.fromJson(value)));
        }

        // Load tips data
        if (data['tips_data'] != null) {
          Map<String, dynamic> tipsDataMap = data['tips_data'];
          _tipsData = tipsDataMap.map((key, value) =>
              MapEntry(key, TipsData.fromJson(value)));
        }

        notifyListeners();
      } catch (e) {
        print('Error loading data: $e');
      }
    }
  }
}