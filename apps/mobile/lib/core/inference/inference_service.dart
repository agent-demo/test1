import '../models/observation.dart';

abstract interface class InferenceService {
  Future<InferenceResult> classify(
      {required String crop, required String imagePath});
}

class InferenceResult {
  const InferenceResult(
      {required this.predictions, required this.abstained, this.reason});

  final List<Prediction> predictions;
  final bool abstained;
  final String? reason;
}
