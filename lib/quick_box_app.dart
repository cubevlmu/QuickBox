/*
 * @Author: cubevlmu khfahqp@gmail.com
 * @LastEditors: cubevlmu khfahqp@gmail.com
 * Copyright (c) 2026 by FlybirdGames, All Rights Reserved. 
 */

import 'package:flutter/material.dart';

import 'pages/launcher_home_page.dart';

class QuickBoxApp extends StatelessWidget {
  const QuickBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF00695C);
    return MaterialApp(
      title: 'Quick Box',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const LauncherHomePage(),
    );
  }
}
