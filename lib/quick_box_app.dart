import 'package:flutter/material.dart';

import 'pages/launcher_home_page.dart';

class QuickBoxApp extends StatelessWidget {
  const QuickBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Box',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const LauncherHomePage(),
    );
  }
}
