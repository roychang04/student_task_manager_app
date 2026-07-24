import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  static const Color backgroundColor = Color(0xFFF6F7FB);

  final CollectionReference<Map<String, dynamic>> _categories =
      FirebaseFirestore.instance.collection('categories');

  final CollectionReference<Map<String, dynamic>> _tasks =
      FirebaseFirestore.instance.collection('tasks');

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _requireUserId() {
    final userId = _currentUserId;
    if (userId == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please log in before managing categories.',
      );
    }
    return userId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _categoryStream {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();

    return _categories
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _taskStream {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();

    return _tasks.where('userId', isEqualTo: userId).snapshots();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'phone':
        return Icons.phone_android_rounded;
      case 'database':
        return Icons.storage_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  Future<bool> _categoryNameExists(
    String name, {
    String? ignoredDocumentId,
  }) async {
    final userId = _requireUserId();
    final snapshot = await _categories
        .where('userId', isEqualTo: userId)
        .get();

    final normalisedName = name.trim().toLowerCase();

    return snapshot.docs.any((document) {
      if (document.id == ignoredDocumentId) return false;

      final existingName =
          document.data()['name']?.toString().trim().toLowerCase() ?? '';
      return existingName == normalisedName;
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveCategory() async {
              final categoryName = controller.text.trim();

              if (categoryName.isEmpty) {
                _showMessage('Please enter a category name.');
                return;
              }

              setDialogState(() => isSaving = true);

              try {
                final userId = _requireUserId();

                if (await _categoryNameExists(categoryName)) {
                  _showMessage('A category with this name already exists.');
                  if (dialogContext.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                  return;
                }

                await _categories.add({
                  'userId': userId,
                  'name': categoryName,
                  'iconKey': 'other',
                  'colorValue': 0xFF6366F1,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('$categoryName was added.');
              } on FirebaseException catch (error) {
                _showMessage(error.message ?? 'Unable to add the category.');
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Add Category'),
              content: TextField(
                controller: controller,
                autofocus: true,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'For example: Software Design',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!isSaving) saveCategory();
                },
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : saveCategory,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showEditCategoryDialog(CategoryData category) async {
    final controller = TextEditingController(text: category.name);
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> updateCategory() async {
              final newName = controller.text.trim();

              if (newName.isEmpty) {
                _showMessage('Please enter a category name.');
                return;
              }

              if (newName.toLowerCase() == category.name.toLowerCase()) {
                Navigator.pop(dialogContext);
                return;
              }

              setDialogState(() => isSaving = true);

              try {
                if (await _categoryNameExists(
                  newName,
                  ignoredDocumentId: category.id,
                )) {
                  _showMessage('A category with this name already exists.');
                  if (dialogContext.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                  return;
                }

                await _renameCategoryAndTasks(
                  category: category,
                  newName: newName,
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('${category.name} was renamed to $newName.');
              } on FirebaseException catch (error) {
                _showMessage(error.message ?? 'Unable to update the category.');
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Category'),
              content: TextField(
                controller: controller,
                autofocus: true,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!isSaving) updateCategory();
                },
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : updateCategory,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _renameCategoryAndTasks({
    required CategoryData category,
    required String newName,
  }) async {
    final userId = _requireUserId();

    if (category.userId != userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'You can only edit your own categories.',
      );
    }

    final userTasks = await _tasks
        .where('userId', isEqualTo: userId)
        .get();

    final matchingTasks = userTasks.docs.where((task) {
      return task.data()['category']?.toString().trim() == category.name;
    });

    final batch = FirebaseFirestore.instance.batch();

    batch.update(_categories.doc(category.id), {
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final task in matchingTasks) {
      batch.update(task.reference, {
        'category': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _confirmDeleteCategory(
    CategoryData category,
    int taskCount,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text(
            taskCount == 0
                ? 'Delete "${category.name}"?'
                : '"${category.name}" is used by $taskCount '
                    '${taskCount == 1 ? 'task' : 'tasks'}. '
                    'A category that is currently in use cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(taskCount == 0 ? 'Cancel' : 'Close'),
            ),
            if (taskCount == 0)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final userId = _requireUserId();

      if (category.userId != userId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'You can only delete your own categories.',
        );
      }

      await _categories.doc(category.id).delete();
      _showMessage('${category.name} was deleted.');
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Unable to delete the category.');
    }
  }

  void _showCategoryOptions(CategoryData category, int taskCount) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit category'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showEditCategoryDialog(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete category',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDeleteCategory(category, taskCount);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _calculateTaskCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
  ) {
    final counts = <String, int>{};

    for (final task in tasks) {
      final categoryName =
          task.data()['category']?.toString().trim() ?? '';
      if (categoryName.isEmpty) continue;
      counts[categoryName] = (counts[categoryName] ?? 0) + 1;
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Categories',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: userId == null ? null : _showAddCategoryDialog,
            icon: const Icon(Icons.add_rounded, color: Colors.black),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: userId == null
          ? const Center(
              child: Text('Please log in to manage categories.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _categoryStream,
              builder: (context, categorySnapshot) {
                if (categorySnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load categories: ${categorySnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (categorySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = categorySnapshot.data?.docs
                        .map(CategoryData.fromDocument)
                        .toList() ??
                    [];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _taskStream,
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load task counts: ${taskSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (taskSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final taskCounts = _calculateTaskCounts(
                      taskSnapshot.data?.docs ?? [],
                    );

                    if (categories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.category_outlined,
                              size: 54,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No categories yet',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create your first category to organise tasks.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Category'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final taskCount = taskCounts[category.name] ?? 0;

                        return CategoryCard(
                          category: category,
                          taskCount: taskCount,
                          icon: _iconFromKey(category.iconKey),
                          onMorePressed: () {
                            _showCategoryOptions(category, taskCount);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final CategoryData category;
  final int taskCount;
  final IconData icon;
  final VoidCallback onMorePressed;

  const CategoryCard({
    super.key,
    required this.category,
    required this.taskCount,
    required this.icon,
    required this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Color(category.colorValue),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$taskCount ${taskCount == 1 ? 'Task' : 'Tasks'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMorePressed,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryData {
  final String id;
  final String userId;
  final String name;
  final String iconKey;
  final int colorValue;

  const CategoryData({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconKey,
    required this.colorValue,
  });

  factory CategoryData.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return CategoryData(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unnamed Category',
      iconKey: data['iconKey']?.toString() ?? 'other',
      colorValue: data['colorValue'] is int
          ? data['colorValue'] as int
          : 0xFF9CA3AF,
    );
  }
}
