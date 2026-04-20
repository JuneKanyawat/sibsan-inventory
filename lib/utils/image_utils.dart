import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  /// Compresses the given [src] bytes in a background isolate using [compute].
  /// This prevents the main UI thread from lagging when processing large images.
  static Future<Uint8List> compressBytes(
    Uint8List src, {
    int maxSide = 1600,
    int quality = 80,
  }) async {
    // Run compression in a background worker to keep UI smooth
    return await compute(_compressInBackground, {
      'src': src,
      'maxSide': maxSide,
      'quality': quality,
    });
  }

  /// Internal helper function that runs in a background isolate.
  static Future<Uint8List> _compressInBackground(
    Map<String, dynamic> args,
  ) async {
    final Uint8List src = args['src'];
    final int maxSide = args['maxSide'];
    final int quality = args['quality'];

    final result = await FlutterImageCompress.compressWithList(
      src,
      minHeight: maxSide,
      minWidth: maxSide,
      quality: quality,
      rotate: 0, // Keep original orientation
    );
    return result;
  }
}
