import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'edit_part_screen.dart';

class PartDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const PartDetailScreen({super.key, required this.docId, required this.data});

  String _formatText(dynamic value) {
    if (value == null) return '-';
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '-';
    return str;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('parts').doc(docId).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> currentData = data;
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          currentData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final barcode = _formatText(currentData['barcode']);
        final name = _formatText(currentData['name']);
        final description = _formatText(currentData['description']);
        final location = _formatText(currentData['location']);
        
        final sellPrice = _formatText(currentData['sell_price']);
        final costPrice = _formatText(currentData['cost_price']);
        final repairPrice = _formatText(currentData['repair_price']);
        final quantity = _formatText(currentData['quantity']);

        final tagsRaw = currentData['tags'];
    String tags = '-';
    if (tagsRaw is List && tagsRaw.isNotEmpty) {
      final validTags = tagsRaw.where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString().trim()).toList();
      if (validTags.isNotEmpty) {
        tags = validTags.join(', ');
      }
    } else if (tagsRaw is String && tagsRaw.trim().isNotEmpty && tagsRaw.toLowerCase() != 'null') {
      tags = tagsRaw;
    }

    final imagePathRaw = currentData['image_url'] ?? currentData['image_path'];
    final imagePath = imagePathRaw?.toString() ?? '';
    final hasImage = imagePath.isNotEmpty && imagePath.toLowerCase() != 'null';

    final compatibleRaw = currentData['compatible_vehicles'];
    List<dynamic> compatibleVehicles = [];
    if (compatibleRaw is List) {
      compatibleVehicles = compatibleRaw;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดอะไหล่'),
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
                      Text('บาร์โค้ด (ID): $barcode', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('ชื่อ (Name): $name', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('สถานที่เก็บ (Location): $location', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('จำนวน (Quantity): $quantity', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('ราคาต้นทุน (Cost Price): ฿ $costPrice', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('ราคาขาย (Sell Price): ฿ $sellPrice', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('ราคาช่างซ่อม (Mechanic Price): ฿ $repairPrice', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('รายละเอียด (Description):', style: const TextStyle(fontSize: 16)),
                      Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text('Tags: $tags', style: const TextStyle(fontSize: 16)),
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
                            builder: (context) => EditPartScreen(
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
                ),
                child: hasImage 
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'ระบบรูปภาพกำลังพัฒนา\n(Image Path Provided)',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 32),
            
            // Compatible Vehicles
            const Text(
              'สามารถใช้กับ:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            if (compatibleVehicles.isEmpty)
              const Text('-', style: TextStyle(fontSize: 16))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: compatibleVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = compatibleVehicles[index];
                  if (vehicle is Map) {
                     final vBrand = _formatText(vehicle['brand']);
                     final vModel = _formatText(vehicle['model']);
                     return Container(
                       margin: const EdgeInsets.only(bottom: 8.0),
                       padding: const EdgeInsets.all(12.0),
                       decoration: BoxDecoration(
                         color: Colors.grey.shade50,
                         border: Border.all(color: Colors.grey.shade300),
                         borderRadius: BorderRadius.circular(8.0),
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.directions_car_outlined, color: Colors.grey),
                           const SizedBox(width: 12),
                           Text('$vBrand $vModel', style: const TextStyle(fontSize: 16)),
                         ],
                       ),
                     );
                  }
                  return Text('- ' + _formatText(vehicle), style: const TextStyle(fontSize: 16));
                },
              ),
              
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
      },
    );
  }
}
