import 'dart:io' show Platform;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../widgets/VideoPlayerWidget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

    // Your backend URL (adjust accordingly)
    final apiUrl = Uri.parse('https://lk-mobile-three.vercel.app/api/videos/$plantName');

    final response = await http.get(apiUrl);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        videoDetails = data.map<Map<String, String>>((item) => {
          'title': item['title'] ?? 'Untitled',
          'url': item['url'],
        }).toList();

        // Sort videos based on P1, P2, etc.
        videoDetails.sort((a, b) {
          final aMatch = RegExp(r'_P(\d+)_').firstMatch(a['title']!);
          final bMatch = RegExp(r'_P(\d+)_').firstMatch(b['title']!);

          final aNum = aMatch != null ? int.tryParse(aMatch.group(1)!) ?? 0 : 0;
          final bNum = bMatch != null ? int.tryParse(bMatch.group(1)!) ?? 0 : 0;

          return aNum.compareTo(bNum);
        });

        isLoadingVideos = false;
      });

      print("✅ Loaded ${videoDetails.length} videos.");
    } else {
      print("❌ Error fetching videos: ${response.body}");
      setState(() => isLoadingVideos = false);
    }
  } catch (e) {
    print("❌ Exception fetching videos: $e");
    setState(() => isLoadingVideos = false);
  }
}

String _formatTitle(String rawTitle) {
  final match = RegExp(r'_P(\d+)_').firstMatch(rawTitle);
  if (match != null && match.groupCount >= 1) {
    final partNumber = match.group(1);
    return 'Part $partNumber';
  }
  return 'Tutorial Video';
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plant['name'] ?? 'Unknown Plant',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.green.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
              minHeight: 10,
            ),
            SizedBox(height: 6),
            Text(
              'Progress: ${progress.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, color: Colors.green.shade800),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _analyzePlantProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              icon: Icon(Icons.camera_alt, color: Colors.white),
              label: Text("Check Progress", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 30),
            Text(
              'Tutorial Videos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
            SizedBox(height: 10),
            isLoadingVideos
                ? Center(child: CircularProgressIndicator())
                : videoDetails.isEmpty
                    ? Text("No videos available.")
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: videoDetails.length,
                        itemBuilder: (context, index) {
                          final video = videoDetails[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTitle(video['title']!),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 8),
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: VideoPlayerWidget(videoUrl: video['url']!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    ),
  );
}

}
