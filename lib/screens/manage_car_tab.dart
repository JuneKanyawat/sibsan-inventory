import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/search_service.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

class ManageCarTab extends StatefulWidget {
  const ManageCarTab({super.key});

  @override
  State<ManageCarTab> createState() => _ManageCarTabState();
}

class _ManageCarTabState extends State<ManageCarTab> {
  String _searchQuery = '';
  // true = A-Z, false = Z-A
  bool _sortAZ = true;
  bool _showSuggestions = true;
  final TextEditingController _searchController = TextEditingController();
  final Stream<QuerySnapshot> _vehiclesStream = FirebaseFirestore.instance
      .collection('vehicles')
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: _vehiclesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Collect all unique brands, models, and tags for suggestions
          final allNames = <String>{};
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final brand = data['brand']?.toString() ?? '';
            final model = data['model']?.toString() ?? '';
            if (brand.isNotEmpty) allNames.add(brand);
            if (model.isNotEmpty) allNames.add(model);
            final tagRaw = data['tag'];
            if (tagRaw is List) {
              for (final t in tagRaw) {
                final ts = t.toString();
                if (ts.isNotEmpty) allNames.add(ts);
              }
            } else if (tagRaw is String && tagRaw.toLowerCase() != 'null' && tagRaw.isNotEmpty) {
              allNames.add(tagRaw);
            }
          }

          // Compute suggestions
          final suggestions = (_searchQuery.length >= 2 && _showSuggestions)
              ? SearchService.getSuggestions(_searchQuery, allNames.toList())
              : <String>[];

          // Filter docs using fuzzy search
          var docs = allDocs;
          if (_searchQuery.isNotEmpty) {
            final queries = _searchQuery.toLowerCase().split(' ').where((q) => q.isNotEmpty).toList();
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final brand = data['brand']?.toString() ?? '';
              final model = data['model']?.toString() ?? '';

              final tagRaw = data['tag'];
              List<String> tags = [];
              if (tagRaw is List) {
                tags = tagRaw.map((e) => e.toString()).toList();
              } else if (tagRaw is String && tagRaw.toLowerCase() != 'null') {
                tags = [tagRaw];
              }

              return queries.every((q) {
                return SearchService.fuzzyMatch(q, brand) ||
                       SearchService.fuzzyMatch(q, model) ||
                       tags.any((t) => SearchService.fuzzyMatch(q, t));
              });
            }).toList();
          }

          // Apply alphabet sort by model name
          final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
          sortedDocs.sort((a, b) {
            final aModel = ((a.data() as Map<String, dynamic>)['model']?.toString() ?? '').toLowerCase();
            final bModel = ((b.data() as Map<String, dynamic>)['model']?.toString() ?? '').toLowerCase();
            return _sortAZ ? aModel.compareTo(bModel) : bModel.compareTo(aModel);
          });

          return Column(
            children: [
              // Search TextField
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                      _showSuggestions = true;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหายี่ห้อ, รุ่นรถ หรือแท็ก...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                ),
              ),

              // Suggestions dropdown
              if (suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'คุณหมายถึง...',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      ...suggestions.map((suggestion) => InkWell(
                        onTap: () {
                          _searchController.text = suggestion;
                          setState(() {
                            _searchQuery = suggestion;
                            _showSuggestions = false;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.search, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.north_west, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),

              // Sort chip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _sortAZ = !_sortAZ;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_by_alpha, size: 16, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              _sortAZ ? 'A → Z' : 'Z → A',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Results list
              Expanded(
                child: sortedDocs.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูลรถยนต์ที่ค้นหา'))
                    : ListView.builder(
                        itemCount: sortedDocs.length,
                        itemBuilder: (context, index) {
                          final data = sortedDocs[index].data() as Map<String, dynamic>;
                          final brand = data['brand']?.toString() ?? 'Brand';
                          final model = data['model']?.toString() ?? 'Model';
                          final year = data['year']?.toString() ?? '-';

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VehicleDetailScreen(
                                    docId: sortedDocs[index].id,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          model, 
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(brand, style: const TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    year, 
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    textAlign: TextAlign.right,
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
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addBtn',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddVehicleScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
