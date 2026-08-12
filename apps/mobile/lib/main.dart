import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'core/inference/mock_inference_service.dart';
import 'core/i18n/app_localizations.dart';
import 'core/media/photo_quality.dart';
import 'core/models/observation.dart';
import 'core/storage/local_store.dart';
import 'core/voice/voice_prompter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  runApp(
      CropSaathiApp(store: store, languageController: AppLanguageController()));
}

class CropSaathiApp extends StatelessWidget {
  const CropSaathiApp(
      {required this.store, required this.languageController, super.key});

  final LocalStore store;
  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Saathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: HomePage(store: store, languageController: languageController),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage(
      {required this.store, required this.languageController, super.key});

  final LocalStore store;
  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: languageController,
          builder: (_, __) => Text(languageController.copy.appName),
        ),
        actions: [
          IconButton(
            tooltip: 'Language',
            onPressed: () => _chooseLanguage(context),
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
                  AnimatedBuilder(
                    animation: languageController,
                    builder: (_, __) => Text(
                        languageController.copy.offlineReady,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Your photos and observations can be saved without internet.\n\nThis is a screening prototype. Uncertain cases should be reviewed by an adviser.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.camera_alt,
            title: languageController.copy.scanCrop,
            subtitle: 'Take clear photos and check symptoms',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ScanPage(
                    store: store, languageController: languageController))),
          ),
          _ActionCard(
            icon: Icons.history,
            title: languageController.copy.history,
            subtitle: 'Saved diagnoses and follow-ups',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HistoryPage(store: store))),
          ),
          _ActionCard(
            icon: Icons.currency_rupee,
            title: languageController.copy.prices,
            subtitle: 'Cached mandi prices and selling guidance',
            onTap: () => _showMessage(
                context, 'Price data will show its source and freshness.'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(languageController.copy.languageLabel),
        children: [
          for (final language in AppLanguage.values)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, language),
                child: Text(language.name)),
        ],
      ),
    );
    if (selected != null) languageController.setLanguage(selected);
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage(
      {required this.store, required this.languageController, super.key});

  final LocalStore store;
  final AppLanguageController languageController;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? crop;
  String? imagePath;
  final symptoms = <String>{};
  bool recentSpray = false;
  bool consent = false;
  bool checkingPhoto = false;
  String? photoMessage;

  static const crops = ['Sugarcane', 'Corn', 'Potato', 'Rice', 'Wheat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.languageController.copy.scanCrop)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('1. ${widget.languageController.copy.chooseCrop}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: crop,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Crop'),
            items: crops
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(() => crop = value),
          ),
          const SizedBox(height: 24),
          Text('2. ${widget.languageController.copy.takePhoto}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                      imagePath == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle,
                      size: 56),
                  const SizedBox(height: 8),
                  const Text(
                      'Take one whole-plant photo and one close-up in daylight.'),
                  if (photoMessage != null)
                    Text(photoMessage!,
                        style: const TextStyle(color: Colors.deepOrange)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                      onPressed: checkingPhoto ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Use camera')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('3. ${widget.languageController.copy.symptoms}',
              style: Theme.of(context).textTheme.titleLarge),
          for (final symptom in const [
            'Leaves have spots or unusual color',
            'Leaves are curling',
            'I can see insects'
          ])
            CheckboxListTile(
                value: symptoms.contains(symptom),
                onChanged: (value) => setState(() => value == true
                    ? symptoms.add(symptom)
                    : symptoms.remove(symptom)),
                title: Text(symptom)),
          SwitchListTile(
              value: recentSpray,
              onChanged: (value) => setState(() => recentSpray = value),
              title: const Text('Sprayed fertilizer or pesticide recently')),
          CheckboxListTile(
              value: consent,
              onChanged: (value) => setState(() => consent = value ?? false),
              title: const Text(
                  'I consent to using this case to improve the model')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: crop == null || imagePath == null || !consent
                ? null
                : () => _showResult(context),
            icon: const Icon(Icons.search),
            label: Text(widget.languageController.copy.screen),
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;
    setState(() => checkingPhoto = true);
    final quality = await PhotoQualityChecker().check(photo.path);
    if (!mounted) return;
    setState(() {
      checkingPhoto = false;
      photoMessage = quality.reason;
      imagePath = quality.accepted ? photo.path : null;
    });
    if (quality.accepted && mounted) {
      await VoicePrompter().speak('Photo saved. You may screen the crop now.',
          widget.languageController.language);
    }
  }

  void _showResult(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultPage(
            crop: crop!,
            store: widget.store,
            imagePath: imagePath!,
            symptoms: symptoms.toList(),
            recentSpray: recentSpray,
            consent: consent)));
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage(
      {required this.crop,
      required this.store,
      required this.imagePath,
      required this.symptoms,
      required this.recentSpray,
      required this.consent,
      super.key});

  final String crop;
  final LocalStore store;
  final String imagePath;
  final List<String> symptoms;
  final bool recentSpray;
  final bool consent;

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
                  Text('Needs review',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      'The first model integration is not yet validated for field images. Please send this case to a verified adviser.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
              leading: const Icon(Icons.grass),
              title: Text(crop),
              subtitle: const Text('Crop selected by farmer')),
          const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Model result'),
              subtitle: Text('Mock inference: integration pending')),
          const ListTile(
              leading: Icon(Icons.cloud_off),
              title: Text('Saved offline'),
              subtitle:
                  Text('This observation can sync when connectivity returns')),
          FilledButton.icon(
              onPressed: () => _saveObservation(context),
              icon: const Icon(Icons.save),
              label: const Text('Save offline and send for review')),
        ],
      ),
    );
  }

  Future<void> _saveObservation(BuildContext context) async {
    final result =
        await MockInferenceService().classify(crop: crop, imagePath: imagePath);
    await store.saveObservation(
      Observation(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        crop: crop.toLowerCase(),
        capturedAt: DateTime.now(),
        modelVersion: 'mock-0.1',
        predictions: result.predictions,
        abstained: result.abstained,
        abstainReason: result.reason,
        symptoms: symptoms,
        recentSpray: recentSpray,
        consentForTraining: consent,
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final observations = snapshot.data!;
          if (observations.isEmpty) {
            return const Center(child: Text('No saved observations yet.'));
          }
          return ListView.builder(
            itemCount: observations.length,
            itemBuilder: (context, index) {
              final observation = observations[index];
              return ListTile(
                leading: Icon(
                    observation.abstained ? Icons.help_outline : Icons.grass),
                title: Text(observation.crop),
                subtitle: Text(
                    '${observation.syncStatus.name} · ${observation.capturedAt.toLocal()}'),
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
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
          leading: Icon(icon, size: 34),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
