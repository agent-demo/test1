import 'inference_service.dart';
import '../models/observation.dart';

class MockInferenceService implements InferenceService {
  @override
  Future<InferenceResult> classify(
      {required String crop, required String imagePath}) async {
    return const InferenceResult(
      predictions: [Prediction(label: 'model_integration_pending', score: 0)],
      abstained: true,
      reason: 'The exported model has not been bundled yet.',
    );
  }
}
