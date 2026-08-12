import 'dart:convert';

class Prediction {
  const Prediction({required this.label, required this.score});

  final String label;
  final double score;

  Map<String, dynamic> toJson() => {'label': label, 'score': score};

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        label: json['label'] as String,
        score: (json['score'] as num).toDouble(),
      );
}

enum SyncStatus { pending, syncing, synced, failed }

class Observation {
  const Observation({
    required this.id,
    required this.crop,
    required this.capturedAt,
    required this.modelVersion,
    required this.predictions,
    required this.abstained,
    this.abstainReason,
    this.consentForTraining = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String crop;
  final DateTime capturedAt;
  final String modelVersion;
  final List<Prediction> predictions;
  final bool abstained;
  final String? abstainReason;
  final bool consentForTraining;
  final SyncStatus syncStatus;

  Observation copyWith({SyncStatus? syncStatus}) => Observation(
        id: id,
        crop: crop,
        capturedAt: capturedAt,
        modelVersion: modelVersion,
        predictions: predictions,
        abstained: abstained,
        abstainReason: abstainReason,
        consentForTraining: consentForTraining,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toStorage() => {
        'id': id,
        'crop': crop,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'model_version': modelVersion,
        'predictions': jsonEncode(predictions.map((item) => item.toJson()).toList()),
        'abstained': abstained ? 1 : 0,
        'abstain_reason': abstainReason,
        'consent_for_training': consentForTraining ? 1 : 0,
        'sync_status': syncStatus.name,
      };

  factory Observation.fromStorage(Map<String, dynamic> row) => Observation(
        id: row['id'] as String,
        crop: row['crop'] as String,
        capturedAt: DateTime.parse(row['captured_at'] as String),
        modelVersion: row['model_version'] as String,
        predictions: (jsonDecode(row['predictions'] as String) as List)
            .map((item) => Prediction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        abstained: row['abstained'] == 1,
        abstainReason: row['abstain_reason'] as String?,
        consentForTraining: row['consent_for_training'] == 1,
        syncStatus: SyncStatus.values.firstWhere(
          (status) => status.name == row['sync_status'],
          orElse: () => SyncStatus.pending,
        ),
      );
}
