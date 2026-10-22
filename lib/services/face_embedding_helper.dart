import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbeddingHelper {
  Interpreter? _interpreter;
  late final FaceDetector _faceDetector;
  bool _isModelLoaded = false;

  FaceEmbeddingHelper() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableClassification: false,
      ),
    );
  }

  // Khởi tạo và nạp mô hình MobileFaceNet
  Future<void> initialize() async {
    if (_isModelLoaded && _interpreter != null) return;

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/mobilefacenet.tflite',
        options: options,
      );
      _isModelLoaded = true;
      debugPrint('MobileFaceNet model loaded successfully.');
    } catch (e) {
      debugPrint('Error loading MobileFaceNet model: $e');
      throw Exception('Không thể nạp mô hình AI mobilefacenet.tflite: $e');
    }
  }

  // Trích xuất vector 128 chiều từ file ảnh chụp
  Future<List<double>> extractEmbedding(String imagePath) async {
    await initialize();

    final inputImage = InputImage.fromFilePath(imagePath);

    // 1. Dùng Google ML Kit Face Detection quét khuôn mặt
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      throw Exception('Không tìm thấy khuôn mặt trong ảnh. Vui lòng căn chỉnh lại!');
    }
    if (faces.length > 1) {
      throw Exception('Phát hiện có ${faces.length} khuôn mặt. Chỉ được có 1 khuôn mặt trong ảnh!');
    }

    final Face face = faces.first;
    final Rect boundingBox = face.boundingBox;

    // 2. Đọc ảnh bằng thư viện image và cắt (crop) khuôn mặt
    final File file = File(imagePath);
    final Uint8List imageBytes = await file.readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      throw Exception('Không thể giải mã file ảnh.');
    }

    // Đảm bảo tọa độ bounding box nằm trong phạm vi kích thước ảnh
    int x = max(0, boundingBox.left.toInt());
    int y = max(0, boundingBox.top.toInt());
    int w = min(boundingBox.width.toInt(), originalImage.width - x);
    int h = min(boundingBox.height.toInt(), originalImage.height - y);

    if (w <= 0 || h <= 0) {
      throw Exception('Khuôn mặt nằm ngoài khung hình hợp lệ.');
    }

    // Cắt khuôn mặt
    final img.Image croppedFace = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    // Resize về kích thước chuẩn của MobileFaceNet: 112 x 112 pixels
    final img.Image resizedFace = img.copyResize(
      croppedFace,
      width: 112,
      height: 112,
    );

    // 3. Chuẩn hóa điểm ảnh (pixel - 127.5) / 128.0 và đóng gói Tensor input [1, 112, 112, 3]
    final Float32List inputBuffer = Float32List(1 * 112 * 112 * 3);
    int pixelIndex = 0;

    for (int row = 0; row < 112; row++) {
      for (int col = 0; col < 112; col++) {
        final pixel = resizedFace.getPixel(col, row);

        // Chuẩn hóa RGB về đoạn [-1, 1]
        final double r = (pixel.r - 127.5) / 128.0;
        final double g = (pixel.g - 127.5) / 128.0;
        final double b = (pixel.b - 127.5) / 128.0;

        inputBuffer[pixelIndex++] = r;
        inputBuffer[pixelIndex++] = g;
        inputBuffer[pixelIndex++] = b;
      }
    }

    final input = inputBuffer.reshape([1, 112, 112, 3]);

    // 4. Xác định kích thước tensor đầu ra của mô hình (ví dụ: [1, 192] hoặc [1, 128])
    final outputTensor = _interpreter!.getOutputTensor(0);
    final int outputDim = outputTensor.shape.last;
    final output = List.generate(1, (_) => List<double>.filled(outputDim, 0.0));

    // 5. Chạy inference qua model MobileFaceNet
    _interpreter!.run(input, output);

    List<double> rawEmbedding = List<double>.from(output[0]);

    // Đảm bảo chính xác 128 chiều tương thích với API Backend
    if (rawEmbedding.length > 128) {
      rawEmbedding = rawEmbedding.sublist(0, 128);
    } else if (rawEmbedding.length < 128) {
      rawEmbedding = List<double>.from(rawEmbedding)
        ..addAll(List.filled(128 - rawEmbedding.length, 0.0));
    }

    // 6. Chuẩn hóa L2 Norm: norm = sqrt(sum(x_i^2)), chia từng phần tử cho norm
    double sumSquares = 0.0;
    for (final val in rawEmbedding) {
      sumSquares += val * val;
    }
    final double norm = sqrt(sumSquares);

    if (norm == 0.0) {
      return rawEmbedding;
    }

    final List<double> normalizedEmbedding = rawEmbedding.map((e) => e / norm).toList();

    return normalizedEmbedding;
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}
