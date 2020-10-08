import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'theme/routes.dart';
import 'views/opening_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Opening View Demo',
      routes: AppRoutes.define(),
      home: OpeningView(),
    );
  }
}
