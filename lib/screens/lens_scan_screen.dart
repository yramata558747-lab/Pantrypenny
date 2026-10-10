
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/pantry_style.dart';

class LensResult {
  final String name;
  final String category;
  final double confidence;
  final String rawText;

  LensResult({
    required this.name,
    required this.category,
    required this.confidence,
    required this.rawText,
  });
}

enum _LensState {
  idle,
  analyzing,
  result,
  error,
}

class LensScanScreen extends StatefulWidget {
  const LensScanScreen({super.key});

  @override
  State<LensScanScreen> createState() =>
      _LensScanScreenState();
}

class _LensScanScreenState extends State<LensScanScreen> {
  _LensState _state = _LensState.idle;

  File? _photo;
  List<ImageLabel> _labels = [];
  String _ocrText = '';
  String? _error;

  int _selectedLabelIndex = 0;

  final TextEditingController _nameCtrl =
      TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();

      if (!mounted) return;

      if (!status.isGranted) {
        setState(() {
          _state = _LensState.error;
          _error =
              'Camera permission is needed to identify items.';
        });
        return;
      }

      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (!mounted || picked == null) return;

      setState(() {
        _photo = File(picked.path);
        _state = _LensState.analyzing;
        _labels = [];
        _ocrText = '';
        _error = null;
      });

      await _analyze(picked.path);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _state = _LensState.error;
        _error = 'Unable to open the camera. '
            'Please check your camera permission.';
      });
    }
  }

  Future<void> _analyze(String path) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: 0.6,
      ),
    );

    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(path);

      final labels =
          await labeler.processImage(inputImage);

      final recognizedText =
          await textRecognizer.processImage(inputImage);

      labels.sort(
        (a, b) =>
            b.confidence.compareTo(a.confidence),
      );

      if (!mounted) return;

      setState(() {
        _labels = labels;
        _ocrText = recognizedText.text.trim();
        _selectedLabelIndex = 0;

        _nameCtrl.text = labels.isNotEmpty
            ? labels.first.label
            : '';

        _state = _LensState.result;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _state = _LensState.error;
        _error =
            'Could not analyze the photo. Please try again.';
      });
    } finally {
      await labeler.close();
      await textRecognizer.close();
    }
  }

  void _retake() {
    setState(() {
      _state = _LensState.idle;
      _photo = null;
      _labels = [];
      _ocrText = '';
      _error = null;
      _selectedLabelIndex = 0;
      _nameCtrl.clear();
    });
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter an item name first.',
          ),
        ),
      );
      return;
    }

    final confidence = _labels.isNotEmpty
        ? _labels[_selectedLabelIndex].confidence
        : 0.0;

    Navigator.pop(
      context,
      LensResult(
        name: name,
        category: _guessCategory(name),
        confidence: confidence,
        rawText: _ocrText,
      ),
    );
  }

  static String _guessCategory(String label) {
    final text = label.toLowerCase();

    const dairy = [
      'milk',
      'cheese',
      'yogurt',
      'butter',
      'cream',
      'egg',
    ];

    const produce = [
      'fruit',
      'vegetable',
      'banana',
      'apple',
      'tomato',
      'onion',
      'potato',
      'carrot',
      'leaf',
    ];

    const grains = [
      'bread',
      'rice',
      'pasta',
      'cereal',
      'flour',
      'bun',
      'noodle',
    ];

    const meat = [
      'meat',
      'chicken',
      'beef',
      'pork',
      'fish',
      'seafood',
      'shrimp',
    ];

    bool matches(List<String> words) {
      return words.any(text.contains);
    }

    if (matches(dairy)) return 'Dairy';
    if (matches(produce)) return 'Produce';
    if (matches(grains)) return 'Grains';
    if (matches(meat)) return 'Meat & Seafood';

    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PantryStyle.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              4,
              0,
              20,
              16,
            ),
            decoration: const BoxDecoration(
              gradient: PantryStyle.headerGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'Identify Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (_state) {
              _LensState.idle => _IdleView(
                  onTakePhoto: _takePhoto,
                ),
              _LensState.analyzing =>
                _AnalyzingView(photo: _photo),
              _LensState.result => _ResultView(
                  photo: _photo,
                  labels: _labels,
                  ocrText: _ocrText,
                  nameCtrl: _nameCtrl,
                  selectedIndex:
                      _selectedLabelIndex,
                  onSelectLabel: (index) {
                    setState(() {
                      _selectedLabelIndex = index;
                      _nameCtrl.text =
                          _labels[index].label;
                    });
                  },
                  onRetake: _retake,
                  onConfirm: _confirm,
                ),
              _LensState.error => _ErrorView(
                  message: _error ??
                      'Something went wrong.',
                  onRetry: _retake,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onTakePhoto;

  const _IdleView({
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PantryStyle.primary.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                size: 45,
                color: PantryStyle.primaryDark,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Snap a photo of an item',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PantryStyle.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'PantryPenny will scan the photo '
              'and suggest an item name for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PantryStyle.inkSoft,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(
                  Icons.camera_alt_rounded,
                ),
                label: const Text('Open Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      PantryStyle.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 17,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'You can review and edit the '
              'detected name before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PantryStyle.inkSoft,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  final File? photo;

  const _AnalyzingView({
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                photo!,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 22),
          const CircularProgressIndicator(
            color: PantryStyle.primaryDark,
          ),
          const SizedBox(height: 16),
          const Text(
            'Analyzing your photo...',
            style: TextStyle(
              color: PantryStyle.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final File? photo;
  final List<ImageLabel> labels;
  final String ocrText;
  final TextEditingController nameCtrl;
  final int selectedIndex;
  final ValueChanged<int> onSelectLabel;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  const _ResultView({
    required this.photo,
    required this.labels,
    required this.ocrText,
    required this.nameCtrl,
    required this.selectedIndex,
    required this.onSelectLabel,
    required this.onRetake,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              photo!,
              height: 205,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'What is this item?',
          style: TextStyle(
            color: PantryStyle.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Select a suggestion or type the '
          'correct product name.',
          style: TextStyle(
            color: PantryStyle.inkSoft,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        if (labels.isEmpty)
          const Text(
            'No confident match found. '
            'Please enter the item name manually.',
            style: TextStyle(
              color: PantryStyle.inkSoft,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              labels.length > 5
                  ? 5
                  : labels.length,
              (index) {
                final label = labels[index];
                final selected =
                    index == selectedIndex;

                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) =>
                      onSelectLabel(index),
                  label: Text(
                    '${label.label} · '
                    '${(label.confidence * 100).round()}%',
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : PantryStyle.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  selectedColor:
                      PantryStyle.primaryDark,
                  backgroundColor:
                      PantryStyle.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(25),
                    side: BorderSide(
                      color: selected
                          ? PantryStyle.primaryDark
                          : PantryStyle.cardBorder,
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: nameCtrl,
          textCapitalization:
              TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Item name',
            hintText: 'Enter correct item name',
            prefixIcon: const Icon(
              Icons.inventory_2_outlined,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
        ),
        if (ocrText.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Text found on packaging',
            style: TextStyle(
              color: PantryStyle.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: PantryStyle.cardBorder,
              ),
            ),
            child: Text(
              ocrText,
              style: const TextStyle(
                color: PantryStyle.inkSoft,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetake,
                icon: const Icon(
                  Icons.replay_rounded,
                ),
                label: const Text('Retake'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      PantryStyle.ink,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(
                  Icons.check_rounded,
                ),
                label: const Text('Use This'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      PantryStyle.primaryDark,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: PantryStyle.danger,
            ),
            const SizedBox(height: 17),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PantryStyle.ink,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    PantryStyle.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
