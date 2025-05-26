// lib/screens/reports_tab.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/tips_provider.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({Key? key}) : super(key: key);

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _isWeightedDistribution = true;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateReport();
    });
  }

  void _generateReport() {
    final provider = Provider.of<TipsProvider>(context, listen: false);
    setState(() {
      _reportData = provider.getMonthlyReport(
        _selectedYear,
        _selectedMonth,
        _isWeightedDistribution,
      );
    });
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Month Tips'),
          content: Text(
            'Are you sure you want to delete ALL tip entries for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}?\n\n'
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final provider = Provider.of<TipsProvider>(context, listen: false);
                provider.resetMonthTips(_selectedYear, _selectedMonth);
                Navigator.of(context).pop();
                _generateReport(); // Refresh report
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Month tips reset successfully')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Future<pw.Document> _generatePDFReport() async {
    if (_reportData == null) {
      // Return empty document if no data
      return pw.Document();
    }

    final pdf = pw.Document();
    final monthYear = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final workerTotals = _reportData!['workerTotals'] as Map<String, Map<String, dynamic>>;

    // Sort by total descending
    final sortedEntries = workerTotals.entries.toList()
      ..sort((a, b) => b.value['total'].compareTo(a.value['total']));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'Tips Report - $monthYear',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Monthly Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Total Tips: €${_reportData!['totalTips'].toStringAsFixed(2)}'),
                    pw.Text('Days with Tips: ${_reportData!['daysWithTips']}'),
                    pw.Text('Distribution Method: ${_isWeightedDistribution ? 'Daily Weighted' : 'Monthly Equal Split'}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Workers table
              pw.Text('Tips Distribution by Worker', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              if (sortedEntries.isNotEmpty)
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Worker', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Tips', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Days Worked', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Avg/Day', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...sortedEntries.map((entry) {
                      final workerName = entry.key;
                      final stats = entry.value;
                      final total = stats['total'] as double;
                      final days = stats['days'] as int;
                      final average = days > 0 ? total / days : 0.0;

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(workerName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('€${total.toStringAsFixed(2)}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(days.toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('€${average.toStringAsFixed(2)}'),
                          ),
                        ],
                      );
                    }),
                  ],
                )
              else
                pw.Text('No tip data found for the selected month'),

              pw.Spacer(),
              pw.Text(
                'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  String _generateCSVReport() {
    if (_reportData == null) return '';

    final monthYear = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final workerTotals = _reportData!['workerTotals'] as Map<String, Map<String, dynamic>>;

    // Sort by total descending
    final sortedEntries = workerTotals.entries.toList()
      ..sort((a, b) => b.value['total'].compareTo(a.value['total']));

    StringBuffer csv = StringBuffer();

    // Header
    csv.writeln('Tips Report - $monthYear');
    csv.writeln('Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    csv.writeln('');

    // Summary
    csv.writeln('Summary');
    csv.writeln('Total Tips,€${_reportData!['totalTips'].toStringAsFixed(2)}');
    csv.writeln('Days with Tips,${_reportData!['daysWithTips']}');
    csv.writeln('Distribution Method,${_isWeightedDistribution ? 'Daily Weighted' : 'Monthly Equal Split'}');
    csv.writeln('');

    // Workers data
    csv.writeln('Worker,Total Tips,Days Worked,Average per Day');

    for (var entry in sortedEntries) {
      final workerName = entry.key;
      final stats = entry.value;
      final total = stats['total'] as double;
      final days = stats['days'] as int;
      final average = days > 0 ? total / days : 0.0;

      csv.writeln('$workerName,€${total.toStringAsFixed(2)},$days,€${average.toStringAsFixed(2)}');
    }

    return csv.toString();
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Report'),
          content: const Text('Choose export format:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _exportAsCSV();
              },
              child: const Text('CSV/Excel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _exportAsPDF();
              },
              child: const Text('PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportAsCSV() async {
    try {
      final csv = _generateCSVReport();
      final monthYear = DateFormat('yyyy-MM').format(DateTime(_selectedYear, _selectedMonth));

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/tips_report_$monthYear.csv');
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tips Report for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
        subject: 'Tips Report - ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV report exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
    }
  }

  Future<void> _exportAsPDF() async {
    try {
      final pdf = await _generatePDFReport();
      final monthYear = DateFormat('yyyy-MM').format(DateTime(_selectedYear, _selectedMonth));

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/tips_report_$monthYear.pdf');
      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tips Report for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
        subject: 'Tips Report - ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isMobile
                  ? Column(
                children: [
                  // Month and Year selectors in a row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(12, (index) {
                            return DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(DateFormat('MMM').format(DateTime(2023, index + 1))),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonth = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(8, (index) {
                            final year = 2023 + index;
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedYear = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Distribution type
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Distribution Type:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              title: const Text('Daily Weighted', style: TextStyle(fontSize: 14)),
                              subtitle: const Text('Based on actual days worked', style: TextStyle(fontSize: 12)),
                              value: true,
                              groupValue: _isWeightedDistribution,
                              dense: true,
                              onChanged: (value) {
                                setState(() {
                                  _isWeightedDistribution = value!;
                                });
                                _generateReport(); // Auto-generate report
                              },
                            ),
                            Divider(height: 1, color: Colors.grey.shade300),
                            RadioListTile<bool>(
                              title: const Text('Monthly Equal', style: TextStyle(fontSize: 14)),
                              subtitle: const Text('Split by days count only', style: TextStyle(fontSize: 12)),
                              value: false,
                              groupValue: _isWeightedDistribution,
                              dense: true,
                              onChanged: (value) {
                                setState(() {
                                  _isWeightedDistribution = false;
                                });
                                _generateReport(); // Auto-generate report
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateReport,
                      child: const Text('Generate Report'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              )
                  : Row(
                children: [
                  // Month selector
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(DateFormat('MMMM').format(DateTime(2023, index + 1))),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMonth = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Year selector
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(8, (index) {
                        final year = 2023 + index;
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Distribution type
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Distribution:', style: TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _isWeightedDistribution,
                            onChanged: (value) {
                              setState(() {
                                _isWeightedDistribution = value!;
                              });
                              _generateReport(); // Auto-generate report
                            },
                          ),
                          const Text('Weighted'),
                          Radio<bool>(
                            value: false,
                            groupValue: _isWeightedDistribution,
                            onChanged: (value) {
                              setState(() {
                                _isWeightedDistribution = false;
                              });
                              _generateReport(); // Auto-generate report
                            },
                          ),
                          const Text('Monthly'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Generate button
                  ElevatedButton(
                    onPressed: _generateReport,
                    child: const Text('Generate\nReport'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Report content
          if (_reportData == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Summary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (isMobile)
                      Column(
                        children: [
                          _buildSummaryItem(
                            'Total Tips for Month',
                            '€${_reportData!['totalTips'].toStringAsFixed(2)}',
                            Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryItem(
                            'Days with Tips',
                            '${_reportData!['daysWithTips']}',
                            null,
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryItem(
                            'Distribution Method',
                            _isWeightedDistribution
                                ? 'Daily Weighted'
                                : 'Monthly Equal Split',
                            null,
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Total Tips for Month'),
                              Text(
                                '€${_reportData!['totalTips'].toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Days with Tips'),
                              Text(
                                '${_reportData!['daysWithTips']}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Distribution Method'),
                              Text(
                                _isWeightedDistribution
                                    ? 'Weighted (by category)'
                                    : 'Days-based (with ratings)',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Workers report
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Tips Distribution by Worker',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildWorkersTable(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Export button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.share, size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'Export & Share Report',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this report via email, messaging apps, or save to your device',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showExportDialog,
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersTable() {
    final workerTotals = _reportData!['workerTotals'] as Map<String, Map<String, dynamic>>;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (workerTotals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text('No tip data found for the selected month'),
        ),
      );
    }

    // Sort by total descending
    final sortedEntries = workerTotals.entries.toList()
      ..sort((a, b) => b.value['total'].compareTo(a.value['total']));

    if (isMobile) {
      // Mobile layout - use cards instead of DataTable
      return Column(
        children: sortedEntries.map((entry) {
          final workerName = entry.key;
          final stats = entry.value;
          final total = stats['total'] as double;
          final days = stats['days'] as int;
          final average = days > 0 ? total / days : 0.0;

          // Get worker category
          final provider = Provider.of<TipsProvider>(context, listen: false);
          final worker = provider.workers[workerName];
          final category = worker?.category ?? 'N/A';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$workerName ($category)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text('Avg/Day: €${average.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 12)),
                            Text(
                              '€${total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Days Worked: $days', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else {
      // Desktop/Tablet layout - use DataTable
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Worker (Category)')),
            DataColumn(label: Text('Total Tips'), numeric: true),
            DataColumn(label: Text('Days Worked'), numeric: true),
            DataColumn(label: Text('Average per Day'), numeric: true),
          ],
          rows: sortedEntries.map((entry) {
            final workerName = entry.key;
            final stats = entry.value;
            final total = stats['total'] as double;
            final days = stats['days'] as int;
            final average = days > 0 ? total / days : 0.0;

            // Get worker category
            final provider = Provider.of<TipsProvider>(context, listen: false);
            final worker = provider.workers[workerName];
            final category = worker?.category ?? 'N/A';

            return DataRow(
              cells: [
                DataCell(Text('$workerName ($category)')),
                DataCell(Text('€${total.toStringAsFixed(2)}')),
                DataCell(Text(days.toString())),
                DataCell(Text('€${average.toStringAsFixed(2)}')),
              ],
            );
          }).toList(),
        ),
      );
    }
  }
}