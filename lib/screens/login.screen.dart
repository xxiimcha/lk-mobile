import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config.dart';
import 'home.screen.dart';
import 'register.screen.dart';
import 'otp.screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _generatedOtp;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('${Config.apiUrl}/api/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        final user = responseData['user'];

        // Generate OTP
        final otp = _generateOtp();
        _generatedOtp = otp;

        // Send OTP via Email
        await _sendOtpEmail(email, otp);

        // Navigate to OTP Verification Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(email: email, generatedOtp: otp, token: token, user: user),
          ),
        );
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['error'] ?? 'Login failed. Please try again.';
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Generates a 6-digit OTP
  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Sends OTP via email using `mailer` package
  Future<void> _sendOtpEmail(String email, String otp) async {
    final smtpServer = SmtpServer(
      Config.smtpHost,
      port: Config.smtpPort,
      username: Config.smtpUsername,
      password: Config.smtpPassword,
      ssl: Config.smtpUseSsl,
    );

    final message = Message()
      ..from = Address(Config.smtpUsername, "Your App Name")
      ..recipients.add(email)
      ..subject = "Your OTP Code"
      ..html = """
          <html>
            <body style="font-family: Arial, sans-serif; text-align: center; background-color: #f3f4f6; padding: 20px;">
              <div style="max-width: 500px; margin: auto; background: #ffffff; padding: 20px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);">
                <h1 style="color: #2E7D32; font-size: 24px;">Luntiang Kamay</h1>
                <h2 style="color: #388E3C; font-size: 22px;">Your OTP Code</h2>
                <p style="font-size: 18px; color: #333;">Use the code below to complete your login process:</p>
                <div style="background: #E8F5E9; padding: 15px; border-radius: 5px; display: inline-block; margin: 10px auto;">
                  <h3 style="color: #1B5E20; font-size: 28px; margin: 0;">$otp</h3>
                </div>
                <p style="color: #555; font-size: 14px;">This OTP is valid for <strong>5 minutes</strong>. Please do not share this code with anyone.</p>
                <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
                <p style="color: #888; font-size: 12px;">Luntiang Kamay - Empowering Sustainability</p>
              </div>
            </body>
          </html>
        """;

    try {
      final sendReport = await send(message, smtpServer);
      print('OTP Sent: ${sendReport.toString()}');
    } catch (e) {
      print('Error sending OTP: $e');
      _showErrorSnackBar('Failed to send OTP. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Image
              Image.asset('assets/logo.png', height: 100),
              SizedBox(height: 24),

              // Title
              Text(
                'Login into your account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  labelStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 20),

              // Password Field
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  labelStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black)),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.green),
                child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
