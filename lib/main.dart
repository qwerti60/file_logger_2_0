//import 'package:crgtransp72app/pages/start_pages.dart';
import 'package:file_logger20/page/login.dart';
import 'package:file_logger20/page/login2.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: LoginPage2());
  }
}
