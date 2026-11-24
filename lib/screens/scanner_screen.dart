import 'package:agvision_scanner/screens/AgVision.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    waitForThreeSecond();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: SizedBox.expand(
          child: Image.asset(
            "assets/splash/splash_screen.jpg",
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void waitForThreeSecond() async {
    await Future.delayed(Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AgVision()),
    );
  }
}
