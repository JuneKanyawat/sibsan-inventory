import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  bool _isImporting = false;
  int _totalItems = 0;
  int _currentItem = 0;
  String _statusMessage = 'พร้อมเริ่มดึงข้อมูล';

  final String _jsonAssetPath = 'lib/assets/cars/inventory3.json';
  final String _imagesAssetBasePath = 'lib/assets/cars/';

  Future<void> _startImport() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'กำลังอ่านไฟล์ JSON...';
    });

    try {
      final jsonString = await rootBundle.loadString(_jsonAssetPath);
      final List<dynamic> jsonData = jsonDecode(jsonString);

      setState(() {
        _totalItems = jsonData.length;
        _statusMessage = 'พบรถยนต์ $_totalItems คัน, กำลังเตรียมอัปโหลด...';
      });

      for (int i = 0; i < jsonData.length; i++) {
        final item = jsonData[i] as Map<String, dynamic>;
        setState(() {
          _currentItem = i + 1;
          _statusMessage = 'อัปโหลดคันที่ $_currentItem / $_totalItems: ${item['brand']} ${item['model']}';
        });

        String imageUrl = '';

        // Handle Image Compression and Upload if available
        if (item['image_path'] != null) {
          String relativePath = item['image_path'].toString().replaceAll('\\', '/');
          String assetImagePath = '$_imagesAssetBasePath$relativePath';
          
          try {
            final byteData = await rootBundle.load(assetImagePath);
            final Uint8List list = byteData.buffer.asUint8List();
            
            // Compress Image
            final Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
              list,
              quality: 70,
            );

            // Upload to Firebase Storage
            final storageRef = FirebaseStorage.instance.ref().child('vehicles/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
            final uploadTask = await storageRef.putData(compressedBytes, SettableMetadata(contentType: 'image/jpeg'));
            imageUrl = await uploadTask.ref.getDownloadURL();
          } catch (e) {
             debugPrint('Image asset not found or error for ${item['brand']}: $assetImagePath\n$e');
          }
        }

        // Prepare Tags
        final tagsStr = item['tags']?.toString() ?? '';
        final tagsList = tagsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        // Write to Firestore Vehicles
        await FirebaseFirestore.instance.collection('vehicles').add({
          'brand': item['brand']?.toString() ?? '',
          'model': item['model']?.toString() ?? '',
          'year': item['year']?.toString() ?? '',
          'tag': tagsList.isNotEmpty ? tagsList : ['-'],
          'description': item['description']?.toString() ?? '',
          'image': imageUrl,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _statusMessage = 'อัปโหลดเสร็จสมบูรณ์ทั้ง $_totalItems คัน!';
        _isImporting = false;
      });

      if (mounted) {
         showDialog(
           context: context,
           builder: (context) => AlertDialog(
             title: const Text('สำเร็จ'),
             content: const Text('การนำเข้าข้อมูลเสร็จสิ้น สามารถตรวจสอบได้ในระบบ'),
             actions: [
               TextButton(
                 onPressed: () { 
                   Navigator.pop(context);
                   Navigator.pop(context); // Go back to correct route
                 },
                 child: const Text('ตกลง'),
               )
             ]
           )
         );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'เกิดข้อผิดพลาด: $e';
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('อิมพอร์ตข้อมูล JSON'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'นำเข้าข้อมูลรถคันใหม่และบีบอัดรูปภาพ',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isImporting) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ],
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (_totalItems > 0 && _isImporting) ...[
                 const SizedBox(height: 16),
                 LinearProgressIndicator(
                   value: _currentItem / _totalItems,
                 ),
                 const SizedBox(height: 8),
                 Text('${(_currentItem / _totalItems * 100).toStringAsFixed(1)}%'),
              ],
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _startImport,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('เริ่มการนำเข้าข้อมูล'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
