// main.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  runApp(const FarmRobotApp());
}

class FarmRobotApp extends StatelessWidget {
  const FarmRobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Farm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B2B1E),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Interpreter? _interpreter;
  List<String> _labels = [];
  File? _image;
  String _result = '';
  String _confidence = '';
  bool _isLoading = false;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // Model Load
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/fruit_model.tflite'
      );

      // Labels load
      final labelsData = await rootBundle.loadString(
          'assets/labels.txt'
      );
      _labels = labelsData
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();

      setState(() => _modelLoaded = true);
      print('Model loaded! Classes: ${_labels.length}');
    } catch (e) {
      print('Model load error: $e');
    }
  }

  // Image Preprocess + Predict
  Future<void> _predict(File imageFile) async {
    if (_interpreter == null) return;

    setState(() => _isLoading = true);

    try {
      // Image read + resize to 224x224
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return;

      img.Image resized = img.copyResize(
          image, width: 224, height: 224
      );

      // Normalize to [0, 1]
      var input = List.generate(1, (_) =>
          List.generate(224, (y) =>
              List.generate(224, (x) {
                final pixel = resized.getPixel(x, y);
                return [
                  pixel.r / 255.0,
                  pixel.g / 255.0,
                  pixel.b / 255.0,
                ];
              })
          )
      );

      // Output shape [1, 24] (24 classes)
      var output = List.generate(
          1, (_) => List.filled(_labels.length, 0.0)
      );

      // Run prediction
      _interpreter!.run(input, output);

      // Get best result
      List<double> scores = output[0];
      int maxIdx = scores.indexOf(
          scores.reduce((a, b) => a > b ? a : b)
      );
      double maxScore = scores[maxIdx] * 100;

      setState(() {
        _result = _labels[maxIdx];
        _confidence = '${maxScore.toStringAsFixed(1)}%';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Pick from Camera
  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = '';
        _confidence = '';
      });
      await _predict(File(picked.path));
    }
  }

  // Pick from Gallery
  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = '';
        _confidence = '';
      });
      await _predict(File(picked.path));
    }
  }

  // Result Color
  Color _getColor(String result) {
    if (result.contains('Ripe') || result.contains('Fresh')) {
      return const Color(0xFF00C853);
    } else if (result.contains('Spoiled')) {
      return const Color(0xFFFF1744);
    } else {
      return const Color(0xFFFFD600);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.eco,
                      color: Color(0xFF00C853), size: 32),
                  const SizedBox(width: 10),
                  const Text('AI Farm',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold,
                          color: Colors.white
                      )
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4
                    ),
                    decoration: BoxDecoration(
                      color: _modelLoaded
                          ? const Color(0xFF00C853).withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _modelLoaded ? 'Model Ready' : 'Loading...',
                      style: TextStyle(
                          color: _modelLoaded
                              ? const Color(0xFF00C853)
                              : Colors.red,
                          fontSize: 12
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Image Display
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3D28),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00C853).withOpacity(0.3),
                        width: 1
                    ),
                  ),
                  child: _image == null
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo,
                          size: 60,
                          color: Color(0xFF00C853)
                      ),
                      SizedBox(height: 16),
                      Text('Take a photo or\nselect from gallery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16
                          )
                      ),
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                        _image!, fit: BoxFit.cover
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Result Card
              if (_isLoading)
                const CircularProgressIndicator(
                    color: Color(0xFF00C853)
                )
              else if (_result.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getColor(_result).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _getColor(_result).withOpacity(0.5),
                        width: 1.5
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(_result,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getColor(_result)
                          )
                      ),
                      const SizedBox(height: 4),
                      Text('Confidence: $_confidence',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70
                          )
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3D28),
                        foregroundColor: const Color(0xFF00C853),
                        side: const BorderSide(
                            color: Color(0xFF00C853)
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}