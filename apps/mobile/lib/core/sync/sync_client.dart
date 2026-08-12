import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/observation.dart';
import '../storage/local_store.dart';

class SyncClient {
  SyncClient({required this.baseUrl, required this.store, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final LocalStore store;
  final http.Client _client;

  Future<SyncSummary> syncPending() async {
    final pending = await store.pendingObservations();
    var synced = 0;
    var failed = 0;
    for (final observation in pending) {
      await store.markSyncStatus(observation.id, SyncStatus.syncing);
      try {
        final response = await _client.post(
          Uri.parse('$baseUrl/api/v1/observations'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'observation_id': observation.id,
            'crop': observation.crop,
            'captured_at': observation.capturedAt.toUtc().toIso8601String(),
            'model_version': observation.modelVersion,
            'predictions': observation.predictions.map((item) => item.toJson()).toList(),
            'abstained': observation.abstained,
            'abstain_reason': observation.abstainReason,
            'consent_for_training': observation.consentForTraining,
          }),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('Sync failed with HTTP ${response.statusCode}');
        }
        await store.markSyncStatus(observation.id, SyncStatus.synced);
        synced++;
      } catch (_) {
        await store.markSyncStatus(observation.id, SyncStatus.failed);
        failed++;
      }
    }
    return SyncSummary(attempted: pending.length, synced: synced, failed: failed);
  }
}

class SyncSummary {
  const SyncSummary({required this.attempted, required this.synced, required this.failed});

  final int attempted;
  final int synced;
  final int failed;
}
