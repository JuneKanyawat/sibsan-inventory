import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/search_service.dart';
import 'add_part_tab.dart';
import 'manage_car_tab.dart';
import 'part_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isBackingUp = false;

  // Placeholder widgets for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    _HomeTab(),
    AddPartTab(),
    ManageCarTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _performBackup() async {
    if (_isBackingUp) return;

    setState(() { _isBackingUp = true; });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('กำลังสำรองข้อมูล...'),
          ],
        ),
      ),
    );

    try {
      final backupService = BackupService();
      await backupService.exportData();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สำรองข้อมูลสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isBackingUp = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color activeIconColor = Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 
              ? 'Sibsan' 
              : _selectedIndex == 1 
                  ? 'Add Part' 
                  : 'Manage Car',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_rounded),
            tooltip: 'สำรองข้อมูล',
            onPressed: _isBackingUp ? null : _performBackup,
          ),
        ],
      ),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Ensure activeIcon works safely across all items
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_rounded, color: activeIconColor),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_circle_outline_rounded),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: activeIconColor,
                ),
              ),
              label: 'Add Part',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.toys_rounded),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.toys_rounded, color: activeIconColor),
              ),
              label: 'Manage Car',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _searchQuery = '';
  // Sort mode: 'date_desc', 'date_asc', 'name_asc', 'name_desc'
  String _sortMode = 'date_desc';
  final TextEditingController _searchController = TextEditingController();
  final Stream<QuerySnapshot> _partsStream = FirebaseFirestore.instance
      .collection('parts')
      .orderBy('created_at', descending: true)
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.black.withValues(alpha: 0.12) 
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? Colors.black.withValues(alpha: 0.4) 
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDateSort = _sortMode.startsWith('date');
    final bool isNameSort = _sortMode.startsWith('name');

    return StreamBuilder<QuerySnapshot>(
      stream: _partsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter docs using fuzzy search
        var docs = allDocs;
        if (_searchQuery.isNotEmpty) {
          final queries = _searchQuery.toLowerCase().split(' ').where((q) => q.isNotEmpty).toList();
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name']?.toString() ?? '';
            final barcode = data['barcode']?.toString() ?? '';
            final tags = (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

            return queries.every((q) {
              return SearchService.fuzzyMatch(q, name) ||
                     SearchService.fuzzyMatch(q, barcode) ||
                     tags.any((tag) => SearchService.fuzzyMatch(q, tag));
            });
          }).toList();
        }

        // Apply sort
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        switch (_sortMode) {
          case 'date_asc':
            sortedDocs.sort((a, b) {
              final aTime = (a.data() as Map<String, dynamic>)['created_at'];
              final bTime = (b.data() as Map<String, dynamic>)['created_at'];
              if (aTime == null || bTime == null) return 0;
              return aTime.compareTo(bTime);
            });
            break;
          case 'name_asc':
            sortedDocs.sort((a, b) {
              final aName = ((a.data() as Map<String, dynamic>)['name']?.toString() ?? '').toLowerCase();
              final bName = ((b.data() as Map<String, dynamic>)['name']?.toString() ?? '').toLowerCase();
              return aName.compareTo(bName);
            });
            break;
          case 'name_desc':
            sortedDocs.sort((a, b) {
              final aName = ((a.data() as Map<String, dynamic>)['name']?.toString() ?? '').toLowerCase();
              final bName = ((b.data() as Map<String, dynamic>)['name']?.toString() ?? '').toLowerCase();
              return bName.compareTo(aName);
            });
            break;
          // 'date_desc' is the default from Firestore query
        }

        return Column(
          children: [
            // Search TextField
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ, บาร์โค้ด หรือแท็ก...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
              ),
            ),


            // Sort chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildSortChip(
                    label: _sortMode == 'date_desc' ? 'ล่าสุด' : 'เก่าสุด',
                    icon: _sortMode == 'date_desc' ? Icons.arrow_downward : Icons.arrow_upward,
                    isActive: isDateSort,
                    onTap: () {
                      setState(() {
                        if (isDateSort) {
                          _sortMode = _sortMode == 'date_desc' ? 'date_asc' : 'date_desc';
                        } else {
                          _sortMode = 'date_desc';
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip(
                    label: _sortMode == 'name_asc' ? 'A → Z' : 'Z → A',
                    icon: Icons.sort_by_alpha,
                    isActive: isNameSort,
                    onTap: () {
                      setState(() {
                        if (isNameSort) {
                          _sortMode = _sortMode == 'name_asc' ? 'name_desc' : 'name_asc';
                        } else {
                          _sortMode = 'name_asc';
                        }
                      });
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${sortedDocs.length} รายการ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Results list
            Expanded(
              child: sortedDocs.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลอะไหล่ที่ค้นหา'))
                  : ListView.builder(
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final data = sortedDocs[index].data() as Map<String, dynamic>;
                        final docId = sortedDocs[index].id;
                        final name = data['name']?.toString() ?? 'Name';
                        final price = data['sell_price']?.toString() ?? '490';
                        final barcode = data['barcode']?.toString() ?? '2345656886';
                        final location = data['location']?.toString() ?? 'C21';

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PartDetailScreen(docId: docId, data: data),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name, 
                                        style: const TextStyle(fontSize: 16),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('- ฿ $price', style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(barcode, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                                    Text(location, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

