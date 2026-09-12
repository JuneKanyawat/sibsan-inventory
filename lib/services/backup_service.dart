import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Exports all Firestore data to a JSON file and opens the Share Sheet.
  /// Returns true if successful, false otherwise.
  Future<bool> exportData() async {
    try {
      // 1. Fetch all data from Firestore
      final partsSnapshot = await _firestore.collection('parts').get();
      final vehiclesSnapshot = await _firestore.collection('vehicles').get();

      // 2. Convert documents to serializable maps
      final parts = partsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ..._convertTimestamps(data),
        };
      }).toList();

      final vehicles = vehiclesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ..._convertTimestamps(data),
        };
      }).toList();

      // 3. Build the backup payload
      final now = DateTime.now();
      final backupData = {
        'app': 'Sibsan Inventory',
        'backup_date': now.toIso8601String(),
        'summary': {
          'total_parts': parts.length,
          'total_vehicles': vehicles.length,
        },
        'parts': parts,
        'vehicles': vehicles,
      };

      // 4. Write JSON to a temporary file
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final dir = await getTemporaryDirectory();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/sibsan_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      // 5. Open Share Sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sibsan Inventory Backup — $dateStr',
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Recursively converts Firestore Timestamps to ISO 8601 strings
  /// so that the data can be serialized to JSON.
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Timestamp) {
        result[entry.key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        result[entry.key] = _convertTimestamps(value);
      } else if (value is List) {
        result[entry.key] = value.map((item) {
          if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else if (item is Map<String, dynamic>) {
            return _convertTimestamps(item);
          }
          return item;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }
}
