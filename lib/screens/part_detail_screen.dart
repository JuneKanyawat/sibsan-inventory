import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'edit_part_screen.dart';
import 'vehicle_detail_screen.dart';

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

    final rawImageUrls = currentData['image_urls'];
    List<String> imageUrls = [];
    if (rawImageUrls is List && rawImageUrls.isNotEmpty) {
      imageUrls = rawImageUrls.map((e) => e.toString()).toList();
    } else {
      final imagePathRaw = currentData['image_url'] ?? currentData['image_path'];
      final imagePath = imagePathRaw?.toString() ?? '';
      if (imagePath.isNotEmpty && imagePath.toLowerCase() != 'null') {
        imageUrls.add(imagePath);
      }
    }

    final compatibleRaw = currentData['compatible_vehicles'];
    List<dynamic> compatibleVehicles = [];
    if (compatibleRaw is List) {
      compatibleVehicles = compatibleRaw;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดอะไหล่'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'กลับหน้าแรก',
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
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
            _ImageSlider(imageUrls: imageUrls),

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
                     return InkWell(
                       onTap: () async {
                          showDialog(
                            context: context, 
                            barrierDismissible: false, 
                            builder: (context) => const Center(child: CircularProgressIndicator())
                          );
                          
                          try {
                            final snapshot = await FirebaseFirestore.instance.collection('vehicles')
                              .where('brand', isEqualTo: vehicle['brand'])
                              .where('model', isEqualTo: vehicle['model'])
                              .limit(1)
                              .get();
                            
                            if (context.mounted) Navigator.pop(context); // close dialog
                            
                            if (snapshot.docs.isNotEmpty) {
                              final doc = snapshot.docs.first;
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VehicleDetailScreen(
                                      docId: doc.id,
                                      data: doc.data(),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ไม่พบข้อมูลรถยนต์รุ่นนี้ในระบบ')),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // close dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                              );
                            }
                          }
                       },
                       child: Container(
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

class _ImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  const _ImageSlider({required this.imageUrls});

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Center(
        child: Container(
          height: 240,
          width: 240,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          width: 240,
          child: PageView.builder(
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _FullScreenGallery(
                        imageUrls: widget.imageUrls,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8.0),
                    image: DecorationImage(
                      image: NetworkImage(widget.imageUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index ? Colors.blue : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ]
      ],
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}', 
          style: const TextStyle(color: Colors.white)
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
