/*
 * @Author: cubevlmu khfahqp@gmail.com
 * @LastEditors: cubevlmu khfahqp@gmail.com
 * Copyright (c) 2026 by FlybirdGames, All Rights Reserved. 
 */

import 'dart:typed_data';

import 'package:flutter/material.dart';

@immutable
class LaunchableApp {
  const LaunchableApp({
    required this.name,
    required this.id,
    required this.hint,
    required this.searchKey,
  });

  final String name;
  final String id;
  final String hint;
  final String searchKey;
}

class AppIconCacheEntry {
  const AppIconCacheEntry({required this.bytes});
  final Uint8List? bytes;
}
