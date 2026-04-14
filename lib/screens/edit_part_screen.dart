import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditPartScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditPartScreen({super.key, required this.docId, required this.initialData});

  @override
  State<EditPartScreen> createState() => _EditPartScreenState();
}

class _EditPartScreenState extends State<EditPartScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _tagController;
  late final TextEditingController _locationController;
  late final TextEditingController _costController;
  late final TextEditingController _sellController;
  late final TextEditingController _repairController;
  late final TextEditingController _quantityController;

  List<Map<String, dynamic>> _vehiclesDb = [];
  String? _selectedBrand;
  String? _selectedModel;

  late List<Map<String, String>> _compatibleVehicles;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    final d = widget.initialData;
    
    _barcodeController = TextEditingController(text: d['barcode']?.toString() ?? '');
    _nameController = TextEditingController(text: d['name']?.toString() ?? '');
    _descController = TextEditingController(text: d['description']?.toString() ?? '');
    
    final tagsRaw = d['tags'];
    String tagsStr = '';
    if (tagsRaw is List) {
      tagsStr = tagsRaw.map((e) => e.toString()).join(', ');
    } else if (tagsRaw is String && tagsRaw != 'null') {
      tagsStr = tagsRaw;
    }
    _tagController = TextEditingController(text: tagsStr);
    
    _locationController = TextEditingController(text: d['location']?.toString() ?? '');
    _costController = TextEditingController(text: d['cost_price']?.toString() ?? '');
    _sellController = TextEditingController(text: d['sell_price']?.toString() ?? '');
    _repairController = TextEditingController(text: d['repair_price']?.toString() ?? '');
    _quantityController = TextEditingController(text: d['quantity']?.toString() ?? '1');

    final compRaw = d['compatible_vehicles'];
    _compatibleVehicles = [];
    if (compRaw is List) {
      for (var v in compRaw) {
        if (v is Map) {
          _compatibleVehicles.add({
            'brand': v['brand']?.toString() ?? '',
            'model': v['model']?.toString() ?? '',
          });
        }
      }
    }

    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vehicles').get();
      if (mounted) {
        setState(() {
          _vehiclesDb = snapshot.docs.map((d) => d.data()).toList();
        });
      }
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
      setState(() {
        _compatibleVehicles.add({
          'brand': _selectedBrand!,
          'model': _selectedModel!,
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

  Future<void> _savePart() async {
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

      final updatedData = {
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
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('parts').doc(widget.docId).update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แก้ไขข้อมูลสำเร็จ')),
        );
        Navigator.pop(context); // Go back to details/home
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลอะไหล่'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                  onPressed: () {},
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
                            _selectedModel = null;
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

              // Photos Section (Placeholder)
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
                        const SizedBox(width: 16),
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
                    onPressed: _isLoading ? null : _savePart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('บันทึกการแก้ไข'),
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
