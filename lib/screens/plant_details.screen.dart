import 'dart:io' show Platform;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../widgets/VideoPlayerWidget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class PlantDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> plant;

  PlantDetailsScreen({required this.plant});

  @override
  _PlantDetailsScreenState createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  final Map<String, Map<String, String>> videoDescriptions = {
    'okra': {
      'P1': 'This video explains the initial steps in planting okra. The speaker starts by introducing the benefits of growing okra...',
      'P2': 'This video is a continuation of the okra planting guide, focusing on plant maintenance and harvesting...',
      'P3': 'This video demonstrates proper pest management techniques for growing okra...',
      'P4': 'This video covers the final stage of okra cultivation, focusing on harvesting, seed saving, and end-of-season care...',
    },
    'sili': {
      'P1': 'This video discusses how to grow chili peppers (sili) in a backyard or garden setting...',
      'P2': 'This video demonstrates how to transplant chili plants into their permanent pots...',
      'P3': 'This part of the video explains the care steps before chili plants start flowering...',
      'P4': 'This part of the video showcases the successful result of properly caring for chili plants...',
    },
    'talong': {
      'P1': 'It showcases the proper techniques for preparing seedbeds, selecting healthy seeds...',
      'P2': 'This video covers the transplanting stage in urban gardening...',
      'P3': 'This video demonstrates the proper application of fertilizer in urban gardening...',
      'P4': 'This video covers the final stage of eggplant cultivation, focusing on harvesting techniques...',
    },
  };

  List<Map<String, String>> videoDetails = [];
  bool isLoadingVideos = true;
  double progress = 0.0;

  String? predictedLabel;
  String? predictedConfidence;
  String? selectedImagePath;

  @override
  void initState() {
    super.initState();
    print("Plant data received: ${widget.plant}");
    _loadVideosFromCloudinary();
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
          final aMatch = RegExp(r'P(\d+)').firstMatch(a['title']!);
          final bMatch = RegExp(r'P(\d+)').firstMatch(b['title']!);

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
  return 'Tutorial Video'; // fallback
}

Future<void> _analyzePlantProgress() async {
  final ImageSource? source = await showDialog<ImageSource>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Select Image Source'),
      actions: [
        TextButton.icon(
          icon: Icon(Icons.photo),
          label: Text('Gallery'),
          onPressed: () => Navigator.pop(context, ImageSource.gallery),
        ),
        TextButton.icon(
          icon: Icon(Icons.camera_alt),
          label: Text('Camera'),
          onPressed: () {
            if (Platform.isAndroid || Platform.isIOS) {
              Navigator.pop(context, ImageSource.camera);
            } else {
              Navigator.pop(context, ImageSource.gallery); // fallback
            }
          },
        ),
      ],
    ),
  );

  if (source == null) {
    print("📛 No image source selected.");
    return;
  }

  final picker = ImagePicker();
  final XFile? imageFile = await picker.pickImage(source: source);

  if (imageFile == null) {
    print("⚠ User canceled image picking.");
    return;
  }

  print("📸 Image picked from: ${imageFile.path}");

  try {
    final uri = Uri.parse('https://lk-flask.onrender.com/predict');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    print("⬆ Sending image to Flask server for analysis...");

    final response = await request.send();

    print("⏳ Waiting for Flask server response...");

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final decoded = jsonDecode(respStr);

      String predictedLabel = decoded['prediction'];
      String predictedConfidence = (decoded['confidence'] * 100).toStringAsFixed(1);

      print("✅ Received prediction from Flask:");
      print("   Label: $predictedLabel");
      print("   Confidence: $predictedConfidence");

      setState(() {
        this.predictedLabel = predictedLabel;
        this.predictedConfidence = predictedConfidence;
        this.progress = double.tryParse(predictedConfidence) ?? 0.0;
        this.selectedImagePath = imageFile.path;
      });

      print("💾 Saving prediction to backend...");
      await _saveProgressToDB(predictedLabel, predictedConfidence);
    } else {
      print("❌ Flask server responded with error: ${response.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Prediction failed: ${response.statusCode}")),
      );
    }
  } catch (e) {
    print("❌ Exception during image upload or analysis: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Prediction failed.")),
    );
  }
}

Future<List<String>> _loadLabels() async {
  final labelString = await DefaultAssetBundle.of(context).loadString('assets/label_names.txt');
  return labelString.split('\n').where((line) => line.trim().isNotEmpty).toList();
}

Uint8List imageToByteListFloat32(img.Image image, int inputSize) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = image.getPixel(x, y);

      final r = (pixel >> 16) & 0xFF;
      final g = (pixel >> 8) & 0xFF;
      final b = (pixel) & 0xFF;

      buffer[pixelIndex++] = r / 255.0;
      buffer[pixelIndex++] = g / 255.0;
      buffer[pixelIndex++] = b / 255.0;
    }
  }

  return convertedBytes.buffer.asUint8List();
}



Future<void> _saveProgressToDB(String label, String confidence) async {
  try {
    final uri = Uri.parse('${Config.apiUrl}/api/seed-requests/update-progress');

    final payload = {
      "userId": widget.plant['userId'],
      "seedType": widget.plant['name'],
      "progress": {
        "label": label.toString(),                 // make sure it's string
        "confidence": double.parse(confidence)     // ensure it's a number, not string
      }
    };

    print('🧾 Sending payload: $payload');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      print("✅ Progress saved successfully");
    } else {
      print("❌ Failed to save progress: ${response.body}");
    }
  } catch (e) {
    print("❌ Error saving progress: $e");
  }
}
  @override
  void dispose() {
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
            SizedBox(height: 16),
            if (predictedLabel != null && predictedConfidence != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (selectedImagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(selectedImagePath!),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prediction:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                          ),
                          Text(
                            predictedLabel!,
                            style: TextStyle(fontSize: 18, color: Colors.black87),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Confidence: $predictedConfidence%',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
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

                          // 🔍 Extract plant key and part (e.g., 'P1')
                          final plantKey = widget.plant['name'].toString().toLowerCase();
                          final partMatch = RegExp(r'P\d+').firstMatch(video['title'] ?? '');
                          final partKey = partMatch != null ? partMatch.group(0)! : '';

                          // 📄 Get the description from the map
                          final description = videoDescriptions[plantKey]?[partKey] ?? 'No description available.';

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
                                  SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(fontSize: 14, color: Colors.black87),
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
