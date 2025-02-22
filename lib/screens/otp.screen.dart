import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String generatedOtp;
  final String token;
  final Map<String, dynamic> user;

  OTPVerificationScreen({required this.email, required this.generatedOtp, required this.token, required this.user});

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  int _secondsRemaining = 300; // 5-minute countdown
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _showErrorSnackBar('OTP expired. Please request a new one.');
      }
    });
  }

  void _verifyOTP() async {
    setState(() {
      _isVerifying = true;
    });

    if (_otpController.text.trim() == widget.generatedOtp) {
      // Save token and user info in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', widget.token);
      await prefs.setString('user', widget.user.toString());

      // Navigate to Home Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      _showErrorSnackBar('Invalid OTP. Please try again.');
    }

    setState(() {
      _isVerifying = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset('assets/logo.png', height: 100), 
            SizedBox(height: 20),

            // Title
            Text(
              'OTP Verification',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[800]),
            ),
            SizedBox(height: 10),

            // Instruction Text
            Text(
              'Enter the OTP sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 20),

            // Countdown Timer
            Text(
              'OTP expires in ${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // OTP Input Field
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _otpController,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  hintText: '6-digit code',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(fontSize: 24, letterSpacing: 8),
              ),
            ),
            SizedBox(height: 20),

            // Verify OTP Button
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isVerifying
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Verify OTP', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 20),

            // Resend OTP Button (Disabled if timer is running)
            TextButton(
              onPressed: _secondsRemaining == 0 ? () => _showErrorSnackBar('Resending OTP not implemented!') : null,
              child: Text(
                'Resend OTP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining == 0 ? Colors.green[700] : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
