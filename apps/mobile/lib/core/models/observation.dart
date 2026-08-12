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
    this.imagePath,
    this.abstainReason,
    this.growthStage,
    this.symptoms = const [],
    this.recentSpray,
    this.approximateLocation,
    this.consentForTraining = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String crop;
  final DateTime capturedAt;
  final String modelVersion;
  final List<Prediction> predictions;
  final bool abstained;
  final String? imagePath;
  final String? abstainReason;
  final String? growthStage;
  final List<String> symptoms;
  final bool? recentSpray;
  final String? approximateLocation;
  final bool consentForTraining;
  final SyncStatus syncStatus;

  Observation copyWith({SyncStatus? syncStatus}) => Observation(
        id: id,
        crop: crop,
        capturedAt: capturedAt,
        modelVersion: modelVersion,
        predictions: predictions,
        abstained: abstained,
        imagePath: imagePath,
        abstainReason: abstainReason,
        growthStage: growthStage,
        symptoms: symptoms,
        recentSpray: recentSpray,
        approximateLocation: approximateLocation,
        consentForTraining: consentForTraining,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toStorage() => {
        'id': id,
        'crop': crop,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'model_version': modelVersion,
        'predictions':
            jsonEncode(predictions.map((item) => item.toJson()).toList()),
        'abstained': abstained ? 1 : 0,
        'image_path': imagePath,
        'abstain_reason': abstainReason,
        'growth_stage': growthStage,
        'symptoms': jsonEncode(symptoms),
        'recent_spray': recentSpray == null ? null : (recentSpray! ? 1 : 0),
        'approximate_location': approximateLocation,
        'consent_for_training': consentForTraining ? 1 : 0,
        'sync_status': syncStatus.name,
      };

  factory Observation.fromStorage(Map<String, dynamic> row) => Observation(
        id: row['id'] as String,
        crop: row['crop'] as String,
        capturedAt: DateTime.parse(row['captured_at'] as String),
        modelVersion: row['model_version'] as String,
        predictions: (jsonDecode(row['predictions'] as String) as List)
            .map((item) =>
                Prediction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        abstained: row['abstained'] == 1,
        imagePath: row['image_path'] as String?,
        abstainReason: row['abstain_reason'] as String?,
        growthStage: row['growth_stage'] as String?,
        symptoms: (jsonDecode(row['symptoms'] as String? ?? '[]') as List)
            .cast<String>(),
        recentSpray:
            row['recent_spray'] == null ? null : row['recent_spray'] == 1,
        approximateLocation: row['approximate_location'] as String?,
        consentForTraining: row['consent_for_training'] == 1,
        syncStatus: SyncStatus.values.firstWhere(
          (status) => status.name == row['sync_status'],
          orElse: () => SyncStatus.pending,
        ),
      );
}
