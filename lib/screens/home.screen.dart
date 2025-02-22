import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sidebar.dart';
import 'plant_details.screen.dart';
import '../config.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSidebarOpen = false;
  String? _userId;

  // List to store plants dynamically added by the user
  final List<Map<String, dynamic>> plants = [];

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      if (_userId != null) {
        _fetchPlants(); // Fetch plants only if _userId is successfully loaded
      } else {
        print('User ID still null after _loadUserId.');
      }
    });
  }

  // Load the user ID from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });

    if (_userId == null) {
      print('User ID not found in SharedPreferences.');
    } else {
      print('Loaded userId: $_userId');
    }
  }
  
  Future<void> _fetchPlants() async {
    if (_userId == null) {
      print('User ID not found, cannot fetch plants.');
      return;
    }

    print('Fetching plants for user ID: $_userId');

    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/api/plants/user-plants/$_userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);

        setState(() {
          plants.clear();

          // Filter only plants with status 'released'
          plants.addAll(responseData.where((data) => data['status'] == 'released').map((data) => {
                'id': data['_id'] ?? '',
                'name': data['seedType'] ?? 'Unknown',
                'progress': (data['progress'] is Map && data['progress'].isNotEmpty)
                  ? _calculateProgress(data['progress']) 
                  : 0.0, // Ensure progress is always a number
              }));
        });

        print('Plants fetched successfully: $plants');
      } else {
        print("Failed to load plants. Status code: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load plants. Please try again later.')),
        );
      }
    } catch (error) {
      print("Error fetching plants: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while fetching plants.')),
      );
    }
  }

  double _calculateProgress(Map<String, dynamic> progressData) {
    // Example: Calculate progress based on the number of completed stages
    int totalStages = progressData.length;
    if (totalStages == 0) return 0.0; 

    int completedStages = progressData.values.where((value) => value == true).length;

    return (completedStages / totalStages) * 100; // Convert to percentage
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
    print('Sidebar toggled: $_isSidebarOpen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Scaffold(
              appBar: AppBar(
                title: Text('Dashboard', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green.shade700,
                leading: IconButton(
                  icon: Icon(Icons.menu, color: Colors.white),
                  onPressed: _toggleSidebar,
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plant Progress Dashboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: plants.isEmpty
                          ? Center(child: Text("No plants added yet.", style: TextStyle(color: Colors.grey.shade600)))
                          : ListView.builder(
                              itemCount: plants.length,
                              itemBuilder: (context, index) {
                                final plant = plants[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlantDetailsScreen(plant: plant),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      title: Text(
                                        plant['name'],
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                      ),
                                      subtitle: Text(
                                        'Progress: ${(plant['progress'] * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(color: Colors.green.shade700),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            left: _isSidebarOpen ? 0 : -250,
            top: 0,
            bottom: 0,
            child: Sidebar(
              isOpen: _isSidebarOpen,
              toggleSidebar: _toggleSidebar,
            ),
          ),
        ],
      ),
    );
  }
}
