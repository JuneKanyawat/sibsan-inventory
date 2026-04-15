import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Picks an image from the specified source (camera or gallery).
  /// Automatically compresses the image to a max width/height of 1080
  /// and roughly 70% quality to save memory and storage.
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70, // 70% quality significantly reduces file size while maintaining clarity
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  /// Uploads the given file to Firebase Storage under the specified path.
  /// Returns the download URL if successful, or null if it fails.
  Future<String?> uploadImage(File imageFile, String folderPath) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String fullPath = '$folderPath/$fileName';
      
      final Reference ref = _storage.ref().child(fullPath);
      final UploadTask uploadTask = ref.putFile(imageFile);
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
}
