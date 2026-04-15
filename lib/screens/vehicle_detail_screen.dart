import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'edit_vehicle_screen.dart'; 

class VehicleDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const VehicleDetailScreen({super.key, required this.docId, required this.data});

  String _formatText(dynamic value) {
    if (value == null) return '-';
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '-';
    return str;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('vehicles').doc(docId).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> currentData = data;
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          currentData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final brand = _formatText(currentData['brand']);
        final model = _formatText(currentData['model']);
        final year = _formatText(currentData['year']);
        final description = _formatText(currentData['description']);
        
        final tagsRaw = currentData['tag'];
        String tags = '-';
        if (tagsRaw is List && tagsRaw.isNotEmpty) {
          final validTags = tagsRaw
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .map((e) => e.toString().trim())
              .toList();
          if (validTags.isNotEmpty) {
            tags = validTags.join(', ');
          }
        } else if (tagsRaw is String && tagsRaw.trim().isNotEmpty && tagsRaw.toLowerCase() != 'null') {
          tags = tagsRaw;
        }

        final imagePathRaw = currentData['image'] ?? currentData['image_url'] ?? currentData['image_path'];
        final imagePath = imagePathRaw?.toString() ?? '';
        final hasImage = imagePath.isNotEmpty && imagePath.toLowerCase() != 'null';

        return Scaffold(
          appBar: AppBar(
            title: const Text('รายละเอียดรถยนต์'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Details Card
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: $docId', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Name: $brand $model', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Year: $year', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Description:', style: TextStyle(fontSize: 16)),
                          Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text('Tag: $tags', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.black87),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditVehicleScreen(
                                  docId: docId,
                                  initialData: currentData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Image Box
                Center(
                  child: Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8.0),
                      image: hasImage ? DecorationImage(
                        image: NetworkImage(imagePath),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: hasImage 
                      ? null
                      : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 32),
                
                const Text(
                  'อะไหล่ที่รองรับ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('parts')
                      .where('compatible_vehicles', arrayContains: {
                        'brand': brand,
                        'model': model,
                      })
                      .snapshots(),
                  builder: (context, partsSnapshot) {
                    if (partsSnapshot.hasError) {
                      return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลอะไหล่'));
                    }
                    if (partsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final partsDocs = partsSnapshot.data?.docs ?? [];

                    if (partsDocs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Center(
                          child: Text(
                            'ยังไม่มีอะไหล่ที่เชื่อมโยงกับรถรุ่นนี้',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: partsDocs.length,
                      itemBuilder: (context, index) {
                        final partData = partsDocs[index].data() as Map<String, dynamic>;
                        final partName = _formatText(partData['name']);
                        final partBarcode = _formatText(partData['barcode']);
                        final partPrice = _formatText(partData['cost_price']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      partName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      partBarcode,
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '- ฿ $partPrice',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
