import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GoogleSignInClient _googleSignIn = GoogleSignInClient(
    scopes: ['email'],
  );

  Future<void> _handleSignIn() async {
    try {
      final account = await _googleSignIn.signInInteractive();

      if (account != null) {
        Navigator.pop(context);
      }
    } catch (error) {
      print('Sign-in error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-up failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', height: 100),
              const SizedBox(height: 24),
              const Text(
                'Sign Up',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign up with Google',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
