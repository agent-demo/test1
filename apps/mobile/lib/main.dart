import 'package:flutter/material.dart';

import 'core/inference/mock_inference_service.dart';
import 'core/models/observation.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  runApp(CropSaathiApp(store: store));
}

class CropSaathiApp extends StatelessWidget {
  const CropSaathiApp({required this.store, super.key});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Saathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: HomePage(store: store),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({required this.store, super.key});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Saathi'),
        actions: [
          IconButton(
            tooltip: 'Language',
            onPressed: () => _showMessage(context, 'Language packs: Hindi, Marathi, Telugu'),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Offline mode ready', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Your photos and observations can be saved without internet.\n\nThis is a screening prototype. Uncertain cases should be reviewed by an adviser.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.camera_alt,
            title: 'Scan a crop',
            subtitle: 'Take clear photos and check symptoms',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScanPage(store: store))),
          ),
          _ActionCard(
            icon: Icons.history,
            title: 'My crop history',
            subtitle: 'Saved diagnoses and follow-ups',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryPage(store: store))),
          ),
          _ActionCard(
            icon: Icons.currency_rupee,
            title: 'Market prices',
            subtitle: 'Cached mandi prices and selling guidance',
            onTap: () => _showMessage(context, 'Price data will show its source and freshness.'),
          ),
        ],
      ),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({required this.store, super.key});

  final LocalStore store;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? crop;
  bool submitted = false;

  static const crops = ['Sugarcane', 'Corn', 'Potato', 'Rice', 'Wheat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop screening')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('1. Choose the crop', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: crop,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Crop'),
            items: crops.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => crop = value),
          ),
          const SizedBox(height: 24),
          Text('2. Take a photo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_outlined, size: 56),
                  SizedBox(height: 8),
                  Text('Photo coach placeholder\nWhole plant plus one close-up will be requested.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('3. Describe symptoms', style: Theme.of(context).textTheme.titleLarge),
          CheckboxListTile(value: submitted, onChanged: (value) => setState(() => submitted = value ?? false), title: const Text('Leaves have spots or unusual color')),
          CheckboxListTile(value: false, onChanged: (_) {}, title: const Text('Leaves are curling')),
          CheckboxListTile(value: false, onChanged: (_) {}, title: const Text('I can see insects')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: crop == null ? null : () => _showResult(context),
            icon: const Icon(Icons.search),
            label: const Text('Screen crop'),
          ),
        ],
      ),
    );
  }

  void _showResult(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultPage(crop: crop!, store: widget.store)));
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({required this.crop, required this.store, super.key});

  final String crop;
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screening result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Colors.amber.shade50,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Needs review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('The first model integration is not yet validated for field images. Please send this case to a verified adviser.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.grass), title: Text(crop), subtitle: const Text('Crop selected by farmer')),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('Model result'), subtitle: Text('Mock inference: integration pending')),
          const ListTile(leading: Icon(Icons.cloud_off), title: Text('Saved offline'), subtitle: Text('This observation can sync when connectivity returns')),
          FilledButton.icon(onPressed: () => _saveObservation(context), icon: const Icon(Icons.save), label: const Text('Save offline and send for review')),
        ],
      ),
    );
  }

  Future<void> _saveObservation(BuildContext context) async {
    final result = await MockInferenceService().classify(crop: crop, imagePath: 'mock');
    await store.saveObservation(
      Observation(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        crop: crop.toLowerCase(),
        capturedAt: DateTime.now(),
        modelVersion: 'mock-0.1',
        predictions: result.predictions,
        abstained: result.abstained,
        abstainReason: result.reason,
        consentForTraining: true,
      ),
    );
    if (context.mounted) {
      _showMessage(context, 'Observation saved offline and queued for review.');
    }
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({required this.store, super.key});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My crop history')),
      body: FutureBuilder<List<Observation>>(
        future: store.listObservations(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final observations = snapshot.data!;
          if (observations.isEmpty) return const Center(child: Text('No saved observations yet.'));
          return ListView.builder(
            itemCount: observations.length,
            itemBuilder: (context, index) {
              final observation = observations[index];
              return ListTile(
                leading: Icon(observation.abstained ? Icons.help_outline : Icons.grass),
                title: Text(observation.crop),
                subtitle: Text('${observation.syncStatus.name} · ${observation.capturedAt.toLocal()}'),
                trailing: const Icon(Icons.chevron_right),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon, size: 34), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
