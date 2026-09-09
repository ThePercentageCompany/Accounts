// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final sourcePath = 'C:\\Users\\irsha\\.gemini\\antigravity-ide\\brain\\a5a71018-3dab-4d72-817e-1d52357d288d\\.user_uploaded\\media_1788982903161.png';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('Error: Source file not found at $sourcePath');
    exit(1);
  }

  final bytes = sourceFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Could not decode source image');
    exit(1);
  }

  print('Source image decoded: ${image.width}x${image.height}');

  // Ensure directories exist
  Directory('web/icons').createSync(recursive: true);
  Directory('assets/images').createSync(recursive: true);

  // 1. Favicon (64x64)
  final fav64 = img.copyResize(image, width: 64, height: 64, interpolation: img.Interpolation.cubic);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(fav64));
  print('Generated web/favicon.png');

  // 2. Icon-192.png
  final icon192 = img.copyResize(image, width: 192, height: 192, interpolation: img.Interpolation.cubic);
  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
  print('Generated web/icons/Icon-192.png');

  // 3. Icon-512.png
  final icon512 = img.copyResize(image, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));
  print('Generated web/icons/Icon-512.png');

  // 4. Icon-maskable-192.png (with slight safe-area padding for maskable icon standards)
  final maskable192 = img.Image(width: 192, height: 192);
  img.fill(maskable192, color: img.ColorRgba8(255, 255, 255, 255));
  final inner192 = img.copyResize(image, width: 154, height: 154, interpolation: img.Interpolation.cubic);
  img.compositeImage(maskable192, inner192, dstX: 19, dstY: 19);
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(maskable192));
  print('Generated web/icons/Icon-maskable-192.png');

  // 5. Icon-maskable-512.png
  final maskable512 = img.Image(width: 512, height: 512);
  img.fill(maskable512, color: img.ColorRgba8(255, 255, 255, 255));
  final inner512 = img.copyResize(image, width: 410, height: 410, interpolation: img.Interpolation.cubic);
  img.compositeImage(maskable512, inner512, dstX: 51, dstY: 51);
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(maskable512));
  print('Generated web/icons/Icon-maskable-512.png');

  // 6. Assets logo.png
  File('assets/images/logo.png').writeAsBytesSync(img.encodePng(image));
  print('Generated assets/images/logo.png');

  // Also Android and iOS icons if directories exist
  print('All icons generated successfully!');
}
