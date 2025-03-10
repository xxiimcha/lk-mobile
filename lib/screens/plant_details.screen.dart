import 'dart:io' show Platform;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PlantDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> plant;

  PlantDetailsScreen({required this.plant});

  @override
  _PlantDetailsScreenState createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  List<Map<String, String>> videoDetails = [];
  List<VideoPlayerController> videoControllers = [];
  bool isLoadingVideos = true;
  int expandedIndex = -1;

  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    print("Plant data received: ${widget.plant}"); // Debugging
    _loadTFLiteModel();
    _loadVideosFromFirebase();
  }

  late tfl.Interpreter _interpreter;

  Future<void> _loadTFLiteModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset("assets/plant_growth_stage_model.tflite");
      print("Model loaded successfully");
    } catch (e) {
      print("Error loading TFLite model: $e");
    }
  }


Future<void> _loadVideosFromFirebase() async {
  try {
    if (widget.plant == null || !widget.plant.containsKey('name') || widget.plant['name'] == null) {
      print("Error: Plant name is missing or null");
      return;
    }

    final seedType = widget.plant['name'].toString().toLowerCase().trim();
    final storageRef = FirebaseStorage.instance.ref().child('videos/$seedType'); // Corrected path

    print("Checking folder in Firebase Storage: videos/$seedType");

    final ListResult result = await storageRef.listAll();

    if (result.items.isEmpty) {
      print("No videos found in: videos/$seedType");
      return;
    }

    print("Files found in folder: videos/$seedType");
    List<Map<String, String>> videos = [];

    for (var ref in result.items) {
      try {
        String url = await ref.getDownloadURL();
        print("Video found: ${ref.name} at $url");

        videos.add({
          'title': ref.name,
          'url': url,
        });
      } catch (e) {
        print("Error fetching video URL for ${ref.name}: $e");
      }
    }

    setState(() {
      videoDetails = videos;
      isLoadingVideos = false;
    });

  } catch (e) {
    print("Error accessing Firebase Storage: $e");
    setState(() {
      isLoadingVideos = false;
    });
  }
}


List<List<List<double>>> preprocessImage(String imagePath) {
  // Load the image
  File imageFile = File(imagePath);
  Uint8List imageBytes = imageFile.readAsBytesSync();
  img.Image? image = img.decodeImage(imageBytes);

  if (image == null) {
    throw Exception("Error decoding image.");
  }

  // Resize the image to match the model input shape (e.g., 224x224)
  img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

  // Convert image pixels to a 3D list (normalized between 0 and 1)
  List<List<List<double>>> input = List.generate(
    224,
    (y) => List.generate(
      224,
      (x) {
        img.Pixel pixel = resizedImage.getPixel(x, y);
        return [
          pixel.r.toDouble() / 255.0, // Normalize R channel
          pixel.g.toDouble() / 255.0, // Normalize G channel
          pixel.b.toDouble() / 255.0, // Normalize B channel
        ];
      },
    ),
  );

  return input;
}
Future<void> _analyzePlantProgress() async {
  final ImagePicker picker = ImagePicker();
  final XFile? imageFile = await picker.pickImage(source: ImageSource.camera);

  if (imageFile == null) {
    print("No image selected.");
    return;
  }

  try {
    // Convert image into required input format for model
    List<List<List<double>>> input = preprocessImage(imageFile.path);
    var output = List.filled(1, 0).reshape([1, 1]); // Modify based on your model's output shape

    _interpreter.run(input, output);

    setState(() {
      progress = output[0][0] * 100;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Progress updated based on analysis!")),
    );

  } catch (e) {
    print("Error analyzing plant progress: $e");
  }
}


  @override
  void dispose() {
    _interpreter.close();
    for (var controller in videoControllers) {
      controller.dispose();
    }
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
                        return ExpansionTile(
                          title: Text(video['title']!, style: TextStyle(fontWeight: FontWeight.bold)),
                          children: [
                            if (videoControllers[index].value.isInitialized)
                              AspectRatio(
                                aspectRatio: videoControllers[index].value.aspectRatio,
                                child: VideoPlayer(videoControllers[index]),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Initializing video...'),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.play_arrow, color: Colors.green),
                                  onPressed: () => videoControllers[index].play(),
                                ),
                                IconButton(
                                  icon: Icon(Icons.pause, color: Colors.red),
                                  onPressed: () => videoControllers[index].pause(),
                                ),
                              ],
                            ),
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
