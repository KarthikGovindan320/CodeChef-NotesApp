import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login.dart';
import 'screens/main.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final username = prefs.getString('username') ?? '';
    if (rememberMe && username.isNotEmpty) {
      return TaskManagerScreen(userId: username);
    }
    return LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIT Compass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasData) {
            return snapshot.data!;
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}
