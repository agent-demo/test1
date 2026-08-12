import 'dart:io';

import 'package:image/image.dart' as image;

class PhotoQuality {
  const PhotoQuality(
      {required this.accepted, required this.reason, this.width, this.height});

  final bool accepted;
  final String reason;
  final int? width;
  final int? height;
}

class PhotoQualityChecker {
  Future<PhotoQuality> check(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const PhotoQuality(
          accepted: false, reason: 'Photo file is missing.');
    }
    final bytes = await file.readAsBytes();
    final decoded = image.decodeImage(bytes);
    if (decoded == null) {
      return const PhotoQuality(
          accepted: false, reason: 'The image could not be read.');
    }
    if (decoded.width < 320 || decoded.height < 320) {
      return PhotoQuality(
          accepted: false,
          reason: 'Move closer and take a larger photo.',
          width: decoded.width,
          height: decoded.height);
    }
    return PhotoQuality(
        accepted: true,
        reason: 'Photo size is usable.',
        width: decoded.width,
        height: decoded.height);
  }
}
