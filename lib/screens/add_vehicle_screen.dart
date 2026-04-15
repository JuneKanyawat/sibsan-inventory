import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  bool _isLoading = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _tagController.dispose();
    super.dispose();
  }


  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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
        'image': 'null',
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

              // Photos Section (Placeholder to match Part Add page)
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
                    const Text('รูปถ่าย', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.add_a_photo, color: Colors.grey),
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
