import 'dart:io' show Platform;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../widgets/VideoPlayerWidget.dart';

class PlantDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> plant;

  PlantDetailsScreen({required this.plant});

  @override
  _PlantDetailsScreenState createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  List<Map<String, String>> videoDetails = [];
  bool isLoadingVideos = true;
  double progress = 0.0;
  late tfl.Interpreter _interpreter;

  @override
  void initState() {
    super.initState();
    print("Plant data received: ${widget.plant}"); // Debugging
    _loadTFLiteModel();
    _loadVideosFromCloudinary();
  }

  Future<void> _loadTFLiteModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset("assets/plant_growth_stage_model.tflite");
      print("✅ Model loaded successfully");
    } catch (e) {
      print("❌ Error loading TFLite model: $e");
    }
  }

  Future<void> _loadVideosFromCloudinary() async {
    try {
      if (widget.plant == null || !widget.plant.containsKey('name') || widget.plant['name'] == null) {
        print("❌ Error: Plant name is missing or null");
        return;
      }

      final plantName = widget.plant['name'].toString().toLowerCase().trim();
      print("🔍 Fetching videos for plant: $plantName");

      // Cloudinary video URL format
      final cloudinaryBaseUrl = "https://res.cloudinary.com/dcavbnkzz/video/cloud_storage/videos/$plantName/";

      // List of videos (Ensure correct video names exist in Cloudinary)
      List<Map<String, String>> videos = [
        {
          'title': 'Planting Guide',
          'url': "${cloudinaryBaseUrl}planting_guide.mp4",
        },
        {
          'title': 'Watering Instructions',
          'url': "${cloudinaryBaseUrl}watering_guide.mp4",
        },
        {
          'title': 'Growth Monitoring',
          'url': "${cloudinaryBaseUrl}growth_monitoring.mp4",
        },
      ];

      print("✅ Video URLs generated:");
      for (var video in videos) {
        print("   - ${video['title']}: ${video['url']}");
      }

      setState(() {
        videoDetails = videos;
        isLoadingVideos = false;
      });

    } catch (e) {
      print("❌ Error loading videos from Cloudinary: $e");
      setState(() {
        isLoadingVideos = false;
      });
    }
  }

  Future<void> _analyzePlantProgress() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(source: ImageSource.camera);

    if (imageFile == null) {
      print("⚠ No image selected.");
      return;
    }

    try {
      List<List<List<double>>> input = preprocessImage(imageFile.path);
      var output = List.filled(1, 0).reshape([1, 1]);

      _interpreter.run(input, output);
      setState(() {
        progress = output[0][0] * 100;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Progress updated based on analysis!")),
      );

    } catch (e) {
      print("❌ Error analyzing plant progress: $e");
    }
  }

  List<List<List<double>>> preprocessImage(String imagePath) {
    File imageFile = File(imagePath);
    Uint8List imageBytes = imageFile.readAsBytesSync();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception("Error decoding image.");
    }

    img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

    List<List<List<double>>> input = List.generate(
      224,
      (y) => List.generate(
        224,
        (x) {
          img.Pixel pixel = resizedImage.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        },
      ),
    );

    return input;
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plant['name']} Details'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plant['name'] ?? 'Unknown Plant',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
            SizedBox(height: 10),
            Text(
              'Progress: ${(progress).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, color: Colors.green.shade700),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _analyzePlantProgress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                "Check Progress",
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Tutorials',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
            SizedBox(height: 10),
            isLoadingVideos
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: videoDetails.length,
                      itemBuilder: (context, index) {
                        final video = videoDetails[index];
                        print("📹 Loading video: ${video['title']} from ${video['url']}");
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video['title']!, style: TextStyle(fontWeight: FontWeight.bold)),
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: VideoPlayerWidget(videoUrl: video['url']!), // Custom Video Player
                            ),
                            SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
