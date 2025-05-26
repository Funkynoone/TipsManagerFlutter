// lib/screens/workers_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tips_provider.dart';
import '../models/worker.dart';

class WorkersTab extends StatefulWidget {
  const WorkersTab({Key? key}) : super(key: key);

  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  final _nameController = TextEditingController();
  final _scrollController = ScrollController(); // Add scroll controller
  String _selectedCategory = 'Service';
  List<bool> _selectedDays = List.filled(7, false);
  bool _isEditing = false;
  String? _editingWorkerName;

  final List<String> _categories = ['Service', 'Cuisine', 'Clean'];
  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _selectedCategory = 'Service';
    _selectedDays = List.filled(7, false);
    _isEditing = false;
    _editingWorkerName = null;
    setState(() {});
  }

  void _saveWorker() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker name is required')),
      );
      return;
    }

    final provider = Provider.of<TipsProvider>(context, listen: false);

    // Check for duplicate names (only if not editing or name changed)
    if (!_isEditing || (_isEditing && name != _editingWorkerName)) {
      if (provider.workers.containsKey(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Worker "$name" already exists')),
        );
        return;
      }
    }

    final workDays = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_selectedDays[i]) workDays.add(i);
    }

    final worker = Worker(
      name: name,
      category: _selectedCategory,
      workDays: workDays,
      rating: Worker.getRatingForCategory(_selectedCategory),
    );

    provider.addOrUpdateWorker(worker);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Worker updated' : 'Worker added')),
    );

    _resetForm();
  }

  void _editWorker(Worker worker) {
    _nameController.text = worker.name;
    _selectedCategory = worker.category;
    _selectedDays = List.filled(7, false);
    for (int day in worker.workDays) {
      _selectedDays[day] = true;
    }
    _isEditing = true;
    _editingWorkerName = worker.name;
    setState(() {});

    // Scroll to top when editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _deleteWorker(String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
            'Are you sure you want to remove worker "$name"?\n\n'
                'This will also remove them from all past and future tip records.\n'
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<TipsProvider>(context, listen: false)
                    .removeWorker(name);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Worker "$name" removed')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TipsProvider>(
      builder: (context, provider, child) {
        final workers = provider.workers.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return SingleChildScrollView(
          controller: _scrollController, // Add controller to SingleChildScrollView
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add/Edit Worker Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Worker' : 'Add Worker',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Name TextField
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isEditing, // Disable editing name during update
                      ),
                      const SizedBox(height: 16),

                      // Work Days
                      const Text('Work Days:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (index) {
                          return FilterChip(
                            label: Text(_dayNames[index]),
                            selected: _selectedDays[index],
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedDays[index] = selected;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Buttons
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _saveWorker,
                            child: Text(_isEditing ? 'Update Worker' : 'Add Worker'),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _resetForm,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Workers List
              Text(
                'Current Workers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              if (workers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('No workers added yet'),
                    ),
                  ),
                )
              else
                ...workers.map((worker) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First row: Name and action buttons
                        Row(
                          children: [
                            // Name takes all available space
                            Expanded(
                              child: Text(
                                worker.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            // Action buttons
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editWorker(worker),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _deleteWorker(worker.name),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Second row: Category and rating
                        Row(
                          children: [
                            Text(
                              '${worker.category} • Rating: x${worker.rating}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Third row: Work days indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(7, (index) {
                              final isWorking = worker.workDays.contains(index);
                              return Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: isWorking ? Colors.green : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    _dayNames[index][0],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isWorking ? Colors.white : Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
            ],
          ),
        );
      },
    );
  }
}