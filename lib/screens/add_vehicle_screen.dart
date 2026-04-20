import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_service.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _tagController = TextEditingController();

  List<File> _selectedImages = [];
  final ImageService _imageService = ImageService();

  bool _isLoading = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _pickImageSource() {
    if (_selectedImages.length >= 3) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คุณสามารถอัปโหลดรูปภาพได้สูงสุด 3 รูปเท่านั้น')));
       return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('ถ่ายรูป (Camera)'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _imageService.pickImage(ImageSource.camera);
                  if (file != null) setState(() { _selectedImages.add(file); });
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ (Gallery)'),
                onTap: () async {
                  Navigator.pop(context);
                  final files = await _imageService.pickMultiImage();
                  if (files.isNotEmpty) {
                    setState(() { 
                      int remaining = 3 - _selectedImages.length;
                      _selectedImages.addAll(files.take(remaining)); 
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final existing = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('brand', isEqualTo: _brandController.text.trim())
          .where('model', isEqualTo: _modelController.text.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('มีข้อมูลรถยนต์ ยี่ห้อ และ รุ่น นี้ในระบบแล้ว')),
          );
          setState(() { _isLoading = false; });
        }
        return;
      }
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final futures = _selectedImages.map((file) => _imageService.uploadImage(file, 'vehicles'));
        final urls = await Future.wait(futures);
        for (var url in urls) {
          if (url != null) imageUrls.add(url);
        }
      }

      final tags = _tagController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final data = {
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': _yearController.text.trim(),
        'tag': tags,
        'image': imageUrls.isNotEmpty ? imageUrls.first : 'null',
        'image_urls': imageUrls,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('vehicles').add(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มข้อมูลรถยนต์สำเร็จ')),
        );
        Navigator.pop(context); // Go back after saving
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'กรุณากรอก $label';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มรถยนต์ (Add Vehicle)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('ยี่ห้อ (Brand)', _brandController),
              _buildTextField('รุ่น (Model)', _modelController),
              _buildTextField('ปี (Year) เช่น 2019-2030', _yearController),
              _buildTextField('tag (คั่นด้วยลูกน้ำ)', _tagController),

              // Photos Section
              Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('รูปถ่าย (สูงสุด 3 รูป)', style: TextStyle(color: Colors.grey)),
                        Text('${_selectedImages.length}/3', 
                            style: TextStyle(color: _selectedImages.length == 3 ? Colors.red : Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ..._selectedImages.asMap().entries.map((entry) {
                          int idx = entry.key;
                          File file = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8.0),
                                  image: DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        if (_selectedImages.length < 3)
                          GestureDetector(
                            onTap: _pickImageSource,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Icon(Icons.add_a_photo, color: Colors.grey),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),

              // Buttons at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('บันทึก'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
