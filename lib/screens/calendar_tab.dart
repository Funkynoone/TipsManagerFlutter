// lib/screens/calendar_tab.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tips_provider.dart';
import '../models/worker.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({Key? key}) : super(key: key);

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late final ValueNotifier<DateTime> _selectedDay;
  late DateTime _focusedDay;
  final _tipsController = TextEditingController();
  final _tipsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedDay = ValueNotifier(DateTime.now());
    _focusedDay = DateTime.now();

    // Add focus listener to clear field when focused
    _tipsFocusNode.addListener(() {
      if (_tipsFocusNode.hasFocus && _tipsController.text == '0.00') {
        _tipsController.clear();
      }
    });

    // Set initial tips value for today
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTipsDisplay();
    });
  }

  @override
  void dispose() {
    _selectedDay.dispose();
    _tipsController.dispose();
    _tipsFocusNode.dispose();
    super.dispose();
  }

  String _getDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _updateTipsDisplay() {
    final provider = Provider.of<TipsProvider>(context, listen: false);
    final dateStr = _getDateString(_selectedDay.value);
    final tipsData = provider.tipsData[dateStr];

    if (tipsData != null) {
      _tipsController.text = tipsData.total.toStringAsFixed(2);
    } else {
      _tipsController.text = '0.00';
    }
  }

  void _saveTips() {
    final amount = double.tryParse(_tipsController.text) ?? 0.0;
    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tips amount cannot be negative')),
      );
      return;
    }

    final provider = Provider.of<TipsProvider>(context, listen: false);
    provider.saveTips(_getDateString(_selectedDay.value), amount);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tips saved')),
    );
  }

  void _showResetConfirmation() {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedDay.value);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Month Tips'),
          content: Text(
            'Are you sure you want to delete ALL tip entries for $monthYear?\n\n'
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
                provider.resetMonthTips(_selectedDay.value.year, _selectedDay.value.month);
                Navigator.of(context).pop();
                setState(() {}); // Refresh UI
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

  void _showAddWorkerDialog() {
    final provider = Provider.of<TipsProvider>(context, listen: false);
    final dateStr = _getDateString(_selectedDay.value);
    final currentWorkers = provider.tipsData[dateStr]?.workers ?? [];

    // Get available workers not already assigned
    final availableWorkers = provider.workers.entries
        .where((entry) => !currentWorkers.contains(entry.key))
        .map((entry) => entry.value)
        .toList();

    if (availableWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All workers are already assigned to this day')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedWorker;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Worker to Day'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Select worker to add:'),
                    const SizedBox(height: 16),
                    ...availableWorkers.map((worker) => RadioListTile<String>(
                      title: Text('${worker.name} (${worker.category})'),
                      value: worker.name,
                      groupValue: selectedWorker,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWorker = value;
                        });
                      },
                    )).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedWorker != null
                      ? () {
                    provider.addWorkerToDate(dateStr, selectedWorker!);
                    Navigator.of(context).pop();
                    setState(() {}); // Refresh UI
                  }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mobile layout only - vertical stack
    return Consumer<TipsProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildTipsEntry(),
              const SizedBox(height: 16),
              _buildCalendarCard(provider),
              const SizedBox(height: 16),
              _buildDateDetailsCard(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipsEntry() {
    return Row(
      children: [
        const Text('Enter Tips: €'),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _tipsController,
            focusNode: _tipsFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onTap: () {
              // Clear the field when tapped if it contains 0.00
              if (_tipsController.text == '0.00') {
                _tipsController.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _saveTips,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(TipsProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Calendar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 350, // Fixed height for mobile
              child: _buildCalendar(provider),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showResetConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Current Month'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDetailsCard(TipsProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildDateDetails(provider),
      ),
    );
  }

  Widget _buildCalendar(TipsProvider provider) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _selectedDay,
      builder: (context, value, _) {
        return TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, value),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: const TextStyle(color: Colors.red),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          eventLoader: (day) {
            final dateStr = _getDateString(day);
            final hasData = provider.tipsData.containsKey(dateStr) &&
                (provider.tipsData[dateStr]!.total > 0);
            return hasData ? ['tips'] : [];
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay.value = selectedDay;
              _focusedDay = focusedDay;
              _updateTipsDisplay();
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        );
      },
    );
  }

  Widget _buildDateDetails(TipsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected date header
        Text(
          'Selected Date',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay.value),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),

        // Current tips display
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tips:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '€${provider.tipsData[_getDateString(_selectedDay.value)]?.total.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Distribution section
        Text(
          'Tip Distribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: _buildDistributionList(provider),
        ),

        const Divider(height: 32),

        // Workers section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Workers for this day',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: _showAddWorkerDialog,
              tooltip: 'Add Worker',
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: _buildWorkersList(provider),
        ),
      ],
    );
  }

  Widget _buildDistributionList(TipsProvider provider) {
    final dateStr = _getDateString(_selectedDay.value);
    final distribution = provider.calculateDistribution(dateStr);

    if (distribution.isEmpty) {
      return const Center(child: Text('No distribution to show'));
    }

    // Sort by amount descending
    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final worker = provider.workers[entry.key];
        final category = worker?.category ?? 'N/A';

        return ListTile(
          dense: true,
          title: Text('${entry.key} ($category)'),
          trailing: Text(
            '€${entry.value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildWorkersList(TipsProvider provider) {
    final dateStr = _getDateString(_selectedDay.value);
    final tipsData = provider.tipsData[dateStr];
    final workers = tipsData?.workers ?? [];

    // If no tips data exists, show default workers for this day
    if (tipsData == null) {
      final dayOfWeek = _selectedDay.value.weekday - 1;
      final defaultWorkers = provider.getWorkersForDay(dayOfWeek);

      if (defaultWorkers.isEmpty) {
        return const Center(child: Text('No workers scheduled for this day'));
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: defaultWorkers.length,
        itemBuilder: (context, index) {
          final worker = defaultWorkers[index];
          return ListTile(
            dense: true,
            title: Text('${worker.name} (${worker.category})'),
            subtitle: const Text('Default assignment'),
            leading: const Icon(Icons.person),
          );
        },
      );
    }

    if (workers.isEmpty) {
      return const Center(child: Text('No workers assigned'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final workerName = workers[index];
        final worker = provider.workers[workerName];
        final category = worker?.category ?? 'N/A';

        return ListTile(
          dense: true,
          title: Text('$workerName ($category)'),
          leading: const Icon(Icons.person),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Remove Worker'),
                    content: Text('Are you sure you want to remove $workerName from this day?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.removeWorkerFromDate(dateStr, workerName);
                          Navigator.of(context).pop();
                          setState(() {}); // Refresh UI
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Remove'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}