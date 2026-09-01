import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_service.dart';

class AddPartTab extends StatefulWidget {
  const AddPartTab({super.key});

  @override
  State<AddPartTab> createState() => _AddPartTabState();
}

class _AddPartTabState extends State<AddPartTab> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _locationController = TextEditingController();
  final _costController = TextEditingController();
  final _sellController = TextEditingController();
  final _repairController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  List<Map<String, dynamic>> _vehiclesDb = [];
  String? _selectedBrand;
  String? _selectedModel;

  List<Map<String, dynamic>> _compatibleVehicles = [];


  List<File> _selectedImages = [];
  final ImageService _imageService = ImageService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicles').get();
        setState(() {
          _vehiclesDb = snapshot.docs.map((d) => {
            ...d.data(),
            'id': d.id,
          }).toList();
        });

    } catch (e) {
      debugPrint("Error fetching vehicles: $e");
    }
  }

  List<String> get _brands {
    final brands = _vehiclesDb.map((v) => v['brand']?.toString() ?? '').where((b) => b.isNotEmpty).toSet().toList();
    brands.sort();
    return brands;
  }

  List<String> _getModelsForBrand(String brand) {
    final models = _vehiclesDb
        .where((v) => v['brand'] == brand)
        .map((v) => v['model']?.toString() ?? '')
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _locationController.dispose();
    _costController.dispose();
    _sellController.dispose();
    _repairController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addVehicle() {
    if (_selectedBrand != null && _selectedModel != null) {
      final exists = _compatibleVehicles.any((v) => 
          v['brand'] == _selectedBrand && v['model'] == _selectedModel);
      
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คุณได้เพิ่มรถรุ่นนี้ไปแล้ว')),
        );
        return;
      }

      setState(() {
        _compatibleVehicles.add({
          'brand': _selectedBrand!,
          'model': _selectedModel!,
          'vehicleId': _vehiclesDb.firstWhere((v) => v['brand'] == _selectedBrand && v['model'] == _selectedModel)['id'],
        });

        _selectedBrand = null;
        _selectedModel = null;
      });
    }
  }

  void _removeVehicle(int index) {
    setState(() {
      _compatibleVehicles.removeAt(index);
    });
  }

  void _clearForm() {
    _barcodeController.clear();
    _nameController.clear();
    _descController.clear();
    _tagController.clear();
    _locationController.clear();
    _costController.clear();
    _sellController.clear();
    _repairController.clear();
    _quantityController.text = '1';
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _compatibleVehicles.clear();
      _selectedImages.clear();
    });
  }

  void _pickImageSource() {
    if (_selectedImages.length >= 5) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คุณสามารถอัปโหลดรูปภาพได้สูงสุด 5 รูปเท่านั้น')));
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
                title: const Text('เลือกหลายรูปจากคลังภาพ (Gallery)'),
                onTap: () async {
                  Navigator.pop(context);
                  final files = await _imageService.pickMultiImage();
                  if (files.isNotEmpty) {
                    setState(() { 
                      int remaining = 5 - _selectedImages.length;
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

  Future<void> _savePart() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final futures = _selectedImages.map((file) => _imageService.uploadImage(file, 'parts'));
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
        'barcode': _barcodeController.text.trim(),
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'tags': tags,
        'location': _locationController.text.trim(),
        'cost_price': num.tryParse(_costController.text.trim()) ?? 0,
        'sell_price': num.tryParse(_sellController.text.trim()) ?? 0,
        'repair_price': num.tryParse(_repairController.text.trim()) ?? 0,
        'quantity': num.tryParse(_quantityController.text.trim()) ?? 0,
        'compatible_vehicles': _compatibleVehicles,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : 'null',
        'image_urls': imageUrls,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('parts').add(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มอะไหล่สำเร็จ')),
        );
        _clearForm();
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

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          suffixIcon: suffixIcon,
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
    return Column(
      children: [
        const SizedBox(height: 16), // keep top padding
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    'บาร์โค้ด',
                    _barcodeController,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.bolt), // Lightning icon
                      onPressed: () {
                        setState(() {
                          _barcodeController.text = DateTime.now().millisecondsSinceEpoch.toString();
                        });
                      },
                    ),
                  ),
                  _buildTextField('ชื่อ', _nameController),
                  _buildTextField('description', _descController),
                  _buildTextField('tag (คั่นด้วยลูกน้ำ)', _tagController),
                  _buildTextField('location', _locationController),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField('ต้นทุน', _costController, isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('ราคาขาย', _sellController, isNumber: true)),
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField('ราคาช่าง', _repairController, isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('จำนวน', _quantityController, isNumber: true)),
                    ],
                  ),

                  // Compatible Vehicles Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: DropdownButtonFormField<String>(
                            value: _selectedBrand,
                            decoration: InputDecoration(
                              labelText: 'ยี่ห้อ (Brand)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                            items: _brands.map((brand) {
                              return DropdownMenuItem(value: brand, child: Text(brand));
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBrand = value;
                                _selectedModel = null; // Reset model when brand changes
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: DropdownButtonFormField<String>(
                            value: _selectedModel,
                            decoration: InputDecoration(
                              labelText: 'รุ่น (Model)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                            items: _selectedBrand == null
                                ? []
                                : _getModelsForBrand(_selectedBrand!).map((model) {
                                    return DropdownMenuItem(value: model, child: Text(model));
                                  }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedModel = value;
                              });
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _addVehicle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('เพิ่มรถที่รองรับ'),
                        ),
                        if (_compatibleVehicles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('รถที่รองรับ:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _compatibleVehicles.length,
                            itemBuilder: (context, index) {
                              final v = _compatibleVehicles[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${v['brand']} - ${v['model']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeVehicle(index),
                                ),
                              );
                            },
                          ),
                        ]
                      ],
                    ),
                  ),

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
                            const Text('รูปถ่าย (สูงสุด 5 รูป)', style: TextStyle(color: Colors.grey)),
                            Text('${_selectedImages.length}/5', style: TextStyle(color: _selectedImages.length == 5 ? Colors.red : Colors.grey)),
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
                            if (_selectedImages.length < 5)
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
                        onPressed: _isLoading ? null : _clearForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: const Text('ล้าง'),
                      ),
                      const SizedBox(width: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _savePart,
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
        ),
      ],
    );
  }
}
