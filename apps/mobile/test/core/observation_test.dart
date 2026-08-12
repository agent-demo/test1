import 'package:flutter_test/flutter_test.dart';
import 'package:crop_saathi/core/models/observation.dart';

void main() {
  test('observation storage round-trip preserves diagnosis and sync state', () {
    final original = Observation(
      id: 'obs-1',
      crop: 'rice',
      capturedAt: DateTime.utc(2026, 8, 12, 10),
      modelVersion: 'mock-0.1',
      predictions: const [Prediction(label: 'brown_spot', score: 0.72)],
      abstained: true,
      abstainReason: 'field shift',
      consentForTraining: true,
      syncStatus: SyncStatus.failed,
    );

    final restored = Observation.fromStorage(original.toStorage());

    expect(restored.id, original.id);
    expect(restored.predictions.single.label, 'brown_spot');
    expect(restored.predictions.single.score, 0.72);
    expect(restored.abstained, isTrue);
    expect(restored.syncStatus, SyncStatus.failed);
  });
}
