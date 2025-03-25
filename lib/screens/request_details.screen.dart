import '../config.dart';
import 'package:flutter/material.dart';

class RequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> request;

  RequestDetailsScreen({required this.request});

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.day}-${date.month}-${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toLowerCase() ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Request Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seed Name
                  Center(
                    child: Text(
                      request['name'] ?? 'Unknown Seed',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Status
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: statusColor),
                      SizedBox(width: 8),
                      Text(
                        'Status: ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        request['status'] ?? 'Pending',
                        style: TextStyle(
                          fontSize: 18,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Description
                  Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    request['description'] ?? 'No description provided.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Created on: ${formatDate(request['createdAt'])}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Image
                  Text(
                    'Attached Image:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: request['imagePath'] != null
                        ? Image.network(
                            request['imagePath'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey.shade300,
                                child: Center(
                                  child: Text(
                                    'Failed to load image.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Text(
                                'No image available.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
