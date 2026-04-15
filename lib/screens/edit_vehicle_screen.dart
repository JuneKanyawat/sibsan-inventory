import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_service.dart';

class EditVehicleScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditVehicleScreen({super.key, required this.docId, required this.initialData});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _tagController;

  String? _existingImageUrl;
  File? _selectedImage;
  final ImageService _imageService = ImageService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _brandController = TextEditingController(text: d['brand']?.toString() ?? '');
    _modelController = TextEditingController(text: d['model']?.toString() ?? '');
    _yearController = TextEditingController(text: d['year']?.toString() ?? '');

    final tagsRaw = d['tag'];
    String tagsStr = '';
    if (tagsRaw is List) {
      tagsStr = tagsRaw.map((e) => e.toString()).join(', ');
    } else if (tagsRaw is String && tagsRaw.toLowerCase() != 'null') {
      tagsStr = tagsRaw;
    }
    _tagController = TextEditingController(text: tagsStr);

    final rawImage = d['image_url'] ?? d['image'];
    if (rawImage != null && rawImage.toString().trim() != 'null' && rawImage.toString().trim().isNotEmpty) {
      _existingImageUrl = rawImage.toString().trim();
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _pickImageSource() {
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
                  if (file != null) setState(() { _selectedImage = file; });
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ (Gallery)'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _imageService.pickImage(ImageSource.gallery);
                  if (file != null) setState(() { _selectedImage = file; });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteVehicle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณตั้งใจที่จะลบข้อมูลรถยนต์นี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('vehicles').doc(widget.docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบข้อมูลรถยนต์สำเร็จ')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')),
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

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl = _existingImageUrl ?? 'null';
      if (_selectedImage != null) {
        final url = await _imageService.uploadImage(_selectedImage!, 'vehicles');
        if (url != null) {
          imageUrl = url;
        }
      }

      final tags = _tagController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedData = {
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': _yearController.text.trim(),
        'tag': tags,
        'image': imageUrl,
      };

      await FirebaseFirestore.instance.collection('vehicles').doc(widget.docId).update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แก้ไขข้อมูลรถยนต์สำเร็จ')),
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
        title: const Text('แก้ไขข้อมูลรถยนต์'),
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
                    const Text('รูปถ่าย (กดเพื่อเปลี่ยน/ถ่ายรูปใหม่)', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImageSource,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8.0),
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(_selectedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_existingImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_existingImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                            ),
                            child: _selectedImage == null && _existingImageUrl == null
                                ? const Icon(Icons.add_a_photo, color: Colors.grey)
                                : null,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // Buttons at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _deleteVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('ลบข้อมูล'),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveVehicle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('บันทึกการแก้ไข'),
                      ),
                    ],
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
