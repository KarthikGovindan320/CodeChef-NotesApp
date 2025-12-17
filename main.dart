import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class Tag {
  final String name;
  final Color color;

  Tag({required this.name, required this.color});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      name: json['name'] ?? '',
      color: Color(int.parse(json['color'].substring(1), radix: 16) +
          0xFF000000),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': '#${color.value.toRadixString(16).substring(2)}',
    };
  }
}

class Task {
  final int? id;
  final String title;
  final String description;
  final bool isCompleted;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<String> tags; // Added tags as a list of tag names

  Task({
    this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.priority = 'medium',
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: int.tryParse(json['id'].toString()),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['is_completed'] == '1' || json['is_completed'] == true,
      priority: json['priority'] ?? 'medium',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      tags: (json['tags'] as List?)?.map((tag) => tag.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'is_completed': isCompleted ? 1 : 0,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'tags': tags,
    };
  }
}

class TaskManagerScreen extends StatefulWidget {
  final String userId;

  const TaskManagerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _TaskManagerScreenState createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> with TickerProviderStateMixin {
  List<Task> tasks = [];
  List<Tag> availableTags = []; 
  bool isLoading = false;
  String selectedFilter = 'all';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<String> predefinedFilters = ['all', 'pending', 'completed', 'high'];

  final String baseUrl = 'https://iunderstandit.in/taskManager.php';
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadTasks();
    _loadTags();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'getTasks',
          'userId': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final fetchedTasks = (data['tasks'] as List).map((taskJson) => Task.fromJson(taskJson)).toList();
          fetchedTasks.sort((a, b) {
            if (a.dueDate == null && b.dueDate != null) return 1;
            if (a.dueDate != null && b.dueDate == null) return -1;
            if (a.dueDate != null && b.dueDate != null) {
              final dateCompare = a.dueDate!.compareTo(b.dueDate!);
              if (dateCompare != 0) return dateCompare;
            }
            final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
            final aPriority = priorityOrder[a.priority.toLowerCase()] ?? 0;
            final bPriority = priorityOrder[b.priority.toLowerCase()] ?? 0;
            return bPriority.compareTo(aPriority);
          });

          setState(() {
            tasks = fetchedTasks;
          });
        } else {
          _showSnackBar(data['message'] ?? 'Failed to load tasks', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'getTags',
          'userId': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            availableTags = (data['tags'] as List).map((tagJson) => Tag.fromJson(tagJson)).toList();
          });
        } else {
          _showSnackBar(data['message'] ?? 'Failed to load tags', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
  }

  Future<bool> _addTag(Tag tag) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'addTag',
          'userId': widget.userId,
          ...tag.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => availableTags.add(tag));
          return true;
        } else {
          _showSnackBar(data['message'] ?? 'Failed to add tag', isError: true);
          return false;
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
    return false;
  }

  Future<void> _deleteTag(String name) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'deleteTag',
          'userId': widget.userId,
          'name': name,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => availableTags.removeWhere((t) => t.name == name));
          _showSnackBar('Tag deleted successfully!');
          _loadTasks();
        } else {
          _showSnackBar(data['message'] ?? 'Failed to delete tag', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _addTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'addTask',
          'userId': widget.userId,
          ...task.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar('Task added successfully!');
          _loadTasks(); 
        } else {
          _showSnackBar(data['message'] ?? 'Failed to add task', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _updateTask(Task task) async {
    if (task.id == null) return;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateTask',
          'userId': widget.userId,
          'taskId': task.id,
          ...task.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _loadTasks();
        } else {
          _showSnackBar(data['message'] ?? 'Failed to update task', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteTask(int taskId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'deleteTask',
          'userId': widget.userId,
          'taskId': taskId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar('Task deleted successfully!');
          _loadTasks();
        } else {
          _showSnackBar(data['message'] ?? 'Failed to delete task', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Task> get filteredTasks {
    switch (selectedFilter) {
      case 'completed':
        return tasks.where((task) => task.isCompleted).toList();
      case 'pending':
        return tasks.where((task) => !task.isCompleted).toList();
      case 'high':
        return tasks.where((task) => task.priority == 'high').toList();
      case 'all':
        return tasks;
      default:
        return tasks.where((task) => task.tags.contains(selectedFilter)).toList();
    }
  }

  bool _matchesSearch(Task task, String query) {
    final lowerQuery = query.toLowerCase();
    final parts = lowerQuery.split(RegExp(r'\s+'));
    String? priorityFilter;
    String? statusFilter;
    List<String> tagFilters = [];
    List<String> searchTerms = [];

    for (var part in parts) {
      if (part.startsWith('priority:')) {
        priorityFilter = part.substring('priority:'.length);
      } else if (part.startsWith('status:')) {
        statusFilter = part.substring('status:'.length);
      } else if (part.startsWith('tag:')) {
        tagFilters.add(part.substring('tag:'.length));
      } else if (part.isNotEmpty) {
        searchTerms.add(part);
      }
    }
    if (priorityFilter != null && task.priority.toLowerCase() != priorityFilter) {
      return false;
    }
    if (statusFilter != null) {
      if (statusFilter == 'pending' && task.isCompleted) return false;
      if (statusFilter == 'completed' && !task.isCompleted) return false;
    }
    for (var tag in tagFilters) {
      if (!task.tags.map((t) => t.toLowerCase()).contains(tag)) {
        return false;
      }
    }
    for (var term in searchTerms) {
      final titleMatch = task.title.toLowerCase().contains(term);
      final descMatch = task.description.toLowerCase().contains(term);
      final priorityMatch = task.priority.toLowerCase().contains(term);
      final statusMatch = (term == 'pending' && !task.isCompleted) ||
                          (term == 'completed' && task.isCompleted);
      final tagMatch = task.tags.any((t) => t.toLowerCase().contains(term));
      if (!(titleMatch || descMatch || priorityMatch || statusMatch || tagMatch)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> tasksToDisplay = _isSearching
        ? (_searchQuery.isEmpty
            ? tasks
            : tasks.where((task) => _matchesSearch(task, _searchQuery)).toList())
        : filteredTasks;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(
                'My Tasks',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
        leading: _isSearching
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  });
                },
              )
            : null,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: Colors.grey[700]),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
            icon: Icon(Icons.label, color: Colors.grey[700]),
            onPressed: _showManageTagsDialog,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (!_isSearching)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('all', 'All Tasks'),
                    _buildFilterChip('pending', 'Pending'),
                    _buildFilterChip('completed', 'Completed'),
                    _buildFilterChip('high', 'High Priority'),
                    ...availableTags.map((tag) => _buildFilterChip(tag.name, tag.name)),
                  ],
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : tasksToDisplay.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tasksToDisplay.length,
                          itemBuilder: (context, index) {
                            return _buildTaskCard(tasksToDisplay[index], index);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(),
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = selectedFilter == value;
    Color? chipColor;
    if (!predefinedFilters.contains(value)) {
      final tag = availableTags.firstWhere(
        (t) => t.name == value,
        orElse: () => Tag(name: value, color: Colors.grey),
      );
      chipColor = tag.color;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (chipColor ?? Colors.grey[700]),
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => selectedFilter = value);
        },
        backgroundColor: Colors.grey[800],
        selectedColor: chipColor?.withOpacity(0.7) ?? Colors.blue[700],
        elevation: isSelected ? 2 : 0,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showTaskDetails(task),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final updatedTask = Task(
                              id: task.id,
                              title: task.title,
                              description: task.description,
                              isCompleted: !task.isCompleted,
                              priority: task.priority,
                              createdAt: task.createdAt,
                              dueDate: task.dueDate,
                              tags: task.tags,
                            );
                            _updateTask(updatedTask);
                          },
                          behavior: HitTestBehavior.opaque, 
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: Container(
                              width: 24,
                              height: 24, 
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.isCompleted ? Colors.green[400] : Colors.transparent,
                                border: Border.all(
                                  color: task.isCompleted ? Colors.green[400]! : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: task.isCompleted
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: task.isCompleted ? Colors.grey[500] : Colors.white,
                                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[300],
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(task.priority).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      task.priority.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getPriorityColor(task.priority),
                                      ),
                                    ),
                                  ),
                                  if (task.dueDate != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.dueDate!.day}/${task.dueDate!.month}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ],
                                ],
                              ),
                              if (task.tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: task.tags.map((tagName) {
                                    final tag = availableTags.firstWhere(
                                      (t) => t.name == tagName,
                                      orElse: () => Tag(name: tagName, color: Colors.grey),
                                    );
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: tag.color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tag.name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: tag.color,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showEditTaskDialog(task);
                                break;
                              case 'delete':
                                _showDeleteConfirmation(task);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddTaskDialog() {
    _showTaskDialog();
  }

  void _showEditTaskDialog(Task task) {
    _showTaskDialog(task: task);
  }

  void _showTaskDialog({Task? task}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(text: task?.description ?? '');
    String selectedPriority = task?.priority ?? 'medium';
    DateTime? selectedDueDate = task?.dueDate;
    List<String> selectedTags = List.from(task?.tags ?? []);
    final newTagController = TextEditingController();
    Color selectedTagColor = Colors.primaries[availableTags.length % Colors.primaries.length];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AbsorbPointer(
          absorbing: isLoading,
          child: Stack(
            children: [
              Dialog(
                backgroundColor: Theme.of(context).dialogBackgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.all(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            task == null ? 'Add Task' : 'Edit Task',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildFormSectionLabel('Title'),
                        TextField(
                          controller: titleController,
                          decoration: _formInputDecoration('Enter task title'),
                        ),
                        const SizedBox(height: 16),
                        _buildFormSectionLabel('Description'),
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: _formInputDecoration('Optional task details'),
                        ),
                        const SizedBox(height: 16),
                        _buildFormSectionLabel('Priority'),
                        DropdownButtonFormField<String>(
                          value: selectedPriority,
                          items: ['low', 'medium', 'high']
                              .map((level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedPriority = value ?? 'medium'),
                          decoration: _formInputDecoration('Select priority'),
                        ),
                        const SizedBox(height: 16),
                        _buildFormSectionLabel('Due Date'),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.grey[900],
                          title: Text(
                            selectedDueDate == null
                                ? 'Tap to set a due date'
                                : '${selectedDueDate!.day}/${selectedDueDate?.month}/${selectedDueDate?.year}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: selectedDueDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.red),
                                  onPressed: () => setDialogState(() => selectedDueDate = null),
                                )
                              : const Icon(Icons.calendar_today, color: Colors.white70),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setDialogState(() => selectedDueDate = picked);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildFormSectionLabel('Tags'),
                        Wrap(
                          spacing: 8,
                          children: availableTags.map((tag) {
                            final isSelected = selectedTags.contains(tag.name);
                            return InputChip(
                              label: Text(tag.name),
                              selected: isSelected,
                              selectedColor: tag.color.withOpacity(0.7),
                              backgroundColor: Colors.grey[800],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                              ),
                              onSelected: (selected) {
                                setDialogState(() {
                                  selected
                                      ? selectedTags.add(tag.name)
                                      : selectedTags.remove(tag.name);
                                });
                              },
                              onDeleted: () async {
                                setDialogState(() => isLoading = true);
                                await _deleteTag(tag.name);
                                setDialogState(() {
                                  availableTags.removeWhere((t) => t.name == tag.name);
                                  selectedTags.remove(tag.name);
                                  isLoading = false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildFormSectionLabel('Create New Tag'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: newTagController,
                                decoration: _formInputDecoration('Enter tag name'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<Color>(
                              value: selectedTagColor,
                              onChanged: (color) => setDialogState(() {
                                selectedTagColor = color!;
                              }),
                              items: Colors.primaries.map((color) {
                                return DropdownMenuItem<Color>(
                                  value: color,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final newTag = newTagController.text.trim();
                                if (newTag.isEmpty) {
                                  _showSnackBar('Tag name cannot be empty.', isError: true);
                                } else if (availableTags.any((t) => t.name == newTag)) {
                                  _showSnackBar('Tag already exists.', isError: true);
                                } else {
                                  setDialogState(() => isLoading = true);
                                  final tag = Tag(name : newTag, color : selectedTagColor);
                                  await _addTag(tag);
                                  setDialogState(() {
                                    selectedTags.add(tag.name);
                                    newTagController.clear();
                                    isLoading = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                backgroundColor: Colors.indigo,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: Text(task == null ? 'Create Task' : 'Update Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                if (titleController.text.trim().isEmpty) {
                                  _showSnackBar('Title cannot be empty', isError: true);
                                  return;
                                }
                                final newTask = Task(
                                  id: task?.id,
                                  title: titleController.text.trim(),
                                  description: descriptionController.text.trim(),
                                  priority: selectedPriority,
                                  createdAt: task?.createdAt ?? DateTime.now(),
                                  dueDate: selectedDueDate,
                                  isCompleted: task?.isCompleted ?? false,
                                  tags: selectedTags,
                                );
                                if (task == null) {
                                  _addTask(newTask);
                                } else {
                                  _updateTask(newTask);
                                }
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    ),
  );

  InputDecoration _formInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.grey[900],
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.description.isNotEmpty) ...[
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(task.description),
                const SizedBox(height: 16),
              ],
              const Text('Priority:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task.priority).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(task.priority),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Created:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}'),
              if (task.dueDate != null) ...[
                const SizedBox(height: 16),
                const Text('Due Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'),
              ],
              const SizedBox(height: 16),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.isCompleted ? 'Completed' : 'Pending'),
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: task.tags.map((tagName) {
                    final tag = availableTags.firstWhere(
                      (t) => t.name == tagName,
                      orElse: () => Tag(name: tagName, color: Colors.grey),
                    );
                    return Chip(
                      label: Text(tag.name),
                      backgroundColor: tag.color.withOpacity(0.2),
                      labelStyle: TextStyle(color: tag.color),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (task.id != null) {
                _deleteTask(task.id!);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showManageTagsDialog() {
    List<Tag> dialogTags = List.from(availableTags);
    final nameController = TextEditingController();
    Color selectedColor = Colors.red;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Manage Tags'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...dialogTags.map((tag) => ListTile(
                  title: Text(tag.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteTag(tag.name);
                      setDialogState(() => dialogTags.removeWhere((t) => t.name == tag.name));
                    },
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: tag.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                )),
                const Divider(),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tag Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Color>(
                  value: selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    Colors.red,
                    Colors.green,
                    Colors.blue,
                    Colors.yellow,
                    Colors.purple,
                    Colors.orange,
                    Colors.pink,
                    Colors.teal,
                  ].map((color) => DropdownMenuItem(
                    value: color,
                    child: Row(
                        children: [
                        Container(width: 24, height: 24, color: color),
                        const SizedBox(width: 8),
                        Text(colorToName(color)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedColor = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showSnackBar('Please enter a tag name', isError: true);
                  return;
                }
                final newTag = Tag(name: name, color: selectedColor);
                final success = await _addTag(newTag);
                if (success) {
                  setDialogState(() => dialogTags.add(newTag));
                  nameController.clear();
                }
              },
              child: const Text('Add Tag'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red[400]!;
      case 'medium':
        return Colors.orange[400]!;
      case 'low':
        return Colors.green[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  String colorToName(Color color) {
    if (color == Colors.red) return 'Red';
    if (color == Colors.green) return 'Green';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.yellow) return 'Yellow';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.orange) return 'Orange';
    if (color == Colors.pink) return 'Pink';
    if (color == Colors.teal) return 'Teal';
    // Fallback for custom or unknown colors
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
