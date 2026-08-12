import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:onnxruntime/onnxruntime.dart';

import '../models/observation.dart';
import 'inference_service.dart';

class OnnxInferenceService implements InferenceService {
  OnnxInferenceService({this.modelAsset = 'assets/models/crop_saathi_v0.onnx'});

  final String modelAsset;
  OrtSession? _session;
  OrtSessionOptions? _options;

  static const labels = <String, List<String>>{
    'sugarcane': ['bacterial_blight', 'healthy', 'red_rot'],
    'corn': ['common_rust', 'gray_leaf_spot', 'healthy'],
    'potato': ['early_blight', 'healthy', 'late_blight'],
    'rice': [
      'brown_spot',
      'healthy',
      'leaf_blast',
      'bacterial_blight',
      'blast',
      'brown_spot_disease',
      'false_smut'
    ],
    'wheat': ['brown_rust', 'healthy', 'yellow_rust'],
  };

  Future<void> _ensureLoaded() async {
    if (_session != null) return;
    OrtEnv.instance.init();
    _options = OrtSessionOptions()
      ..setIntraOpNumThreads(1)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final asset = await rootBundle.load(modelAsset);
    _session = OrtSession.fromBuffer(asset.buffer.asUint8List(), _options!);
  }

  @override
  Future<InferenceResult> classify(
      {required String crop, required String imagePath}) async {
    final normalizedCrop = crop.toLowerCase();
    if (!labels.containsKey(normalizedCrop)) {
      return const InferenceResult(
          predictions: [],
          abstained: true,
          reason: 'This crop is not supported by the bundled model.');
    }
    try {
      await _ensureLoaded();
      final bytes = image.decodeImage(await File(imagePath).readAsBytes());
      if (bytes == null) throw StateError('Image could not be decoded');
      final input = OrtValueTensor.createTensorWithDataList(
          _preprocess(bytes), [1, 3, 224, 224]);
      final options = OrtRunOptions();
      final outputs = _session!.run(options, {'pixel_values': input});
      final raw = (outputs.first?.value as List<List<double>>).first;
      input.release();
      options.release();
      for (final output in outputs) {
        output?.release();
      }
      final ranked = _rankCropLabels(raw, normalizedCrop);
      if (ranked.isEmpty ||
          ranked.first.score < 0.85 ||
          (ranked.length > 1 && ranked.first.score - ranked[1].score < 0.15)) {
        return InferenceResult(
            predictions: ranked,
            abstained: true,
            reason:
                'The model is not sufficiently certain for this field image.');
      }
      return InferenceResult(predictions: ranked, abstained: false);
    } catch (error) {
      return InferenceResult(
          predictions: const [],
          abstained: true,
          reason: 'Offline model could not run: $error');
    }
  }

  List<Prediction> _rankCropLabels(List<double> logits, String crop) {
    final cropLabels = labels[crop]!;
    final indices = _indicesForCrop(crop);
    final selected = [
      for (var i = 0; i < indices.length; i++)
        (i: indices[i], label: cropLabels[i], value: logits[indices[i]])
    ];
    final maxLogit = selected.map((item) => item.value).reduce(math.max);
    final denominator = selected
        .map((item) => math.exp(item.value - maxLogit))
        .reduce((a, b) => a + b);
    final predictions = selected
        .map((item) => Prediction(
            label: item.label,
            score: math.exp(item.value - maxLogit) / denominator))
        .toList();
    predictions.sort((a, b) => b.score.compareTo(a.score));
    return predictions;
  }

  List<int> _indicesForCrop(String crop) => switch (crop) {
        'corn' => [0, 1, 2],
        'potato' => [4, 5, 6],
        'rice' => [7, 8, 9, 13, 14, 15, 16],
        'wheat' => [10, 11, 12],
        'sugarcane' => [17, 18, 19],
        _ => const [],
      };

  Float32List _preprocess(image.Image source) {
    final resized = image.copyResize(source, width: 224, height: 224);
    final values = Float32List(3 * 224 * 224);
    var offset = 0;
    for (var channel = 0; channel < 3; channel++) {
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          final value = channel == 0
              ? pixel.r
              : channel == 1
                  ? pixel.g
                  : pixel.b;
          values[offset++] = (value / 255.0 - 0.5) / 0.5;
        }
      }
    }
    return values;
  }

  void release() {
    _session?.release();
    _session = null;
    _options?.release();
    _options = null;
  }
}
