/*
 * @Author: cubevlmu khfahqp@gmail.com
 * @LastEditors: cubevlmu khfahqp@gmail.com
 * Copyright (c) 2026 by FlybirdGames, All Rights Reserved. 
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/launchable_app.dart';

class AppLauncherService {
  static const MethodChannel _channel = MethodChannel('quick_box/launcher');
  static List<LaunchableApp>? _cachedApps;
  static String? _iconCacheDir;
  static final Map<String, AppIconCacheEntry> _iconCache =
      <String, AppIconCacheEntry>{};
  static final Map<String, ValueNotifier<Uint8List?>> _iconNotifiers =
      <String, ValueNotifier<Uint8List?>>{};
  static final Map<String, Future<Uint8List?>> _iconInFlight =
      <String, Future<Uint8List?>>{};
  static final Set<String> _diskReadInFlight = <String>{};

  static Future<List<LaunchableApp>> getApps({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _cachedApps = null;
      _iconCache.clear();
      _iconInFlight.clear();
      for (final ValueNotifier<Uint8List?> notifier in _iconNotifiers.values) {
        notifier.value = null;
      }
    }

    if (!forceRefresh && _cachedApps != null) {
      return _cachedApps!;
    }

    final List<LaunchableApp> apps;
    if (kIsWeb || !Platform.isAndroid) {
      apps = <LaunchableApp>[];
    } else {
      apps = await _loadAndroidApps();
    }

    _cachedApps = apps;
    return apps;
  }

  static Future<bool> launch(LaunchableApp app) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    final bool? ok = await _channel.invokeMethod<bool>(
      'launchApp',
      <String, Object>{'packageName': app.id},
    );
    return ok ?? false;
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    if (packageName.isEmpty) return null;

    final AppIconCacheEntry? cached = _iconCache[packageName];
    if (cached != null) return cached.bytes;

    final Uint8List? diskCached = await _readIconFromDisk(packageName);
    if (diskCached != null) {
      _setIcon(packageName, diskCached);
      return diskCached;
    }

    final Future<Uint8List?>? running = _iconInFlight[packageName];
    if (running != null) return running;

    final Future<Uint8List?> task = _fetchAppIcon(packageName);
    _iconInFlight[packageName] = task;

    try {
      final Uint8List? bytes = await task;
      _iconCache[packageName] = AppIconCacheEntry(bytes: bytes);
      final ValueNotifier<Uint8List?> notifier = _iconNotifiers.putIfAbsent(
        packageName,
        () => ValueNotifier<Uint8List?>(null),
      );
      notifier.value = bytes;
      return bytes;
    } finally {
      _iconInFlight.remove(packageName);
    }
  }

  static Future<int> fetchIconsBatch(List<String> packageNames) async {
    if (kIsWeb || !Platform.isAndroid || packageNames.isEmpty) return 0;

    final int diskAdded = await _hydrateIconsFromDisk(packageNames);

    final List<String> missing = packageNames
        .where((String packageName) => !_iconCache.containsKey(packageName))
        .toSet()
        .toList();
    if (missing.isEmpty) return diskAdded;

    try {
      final Map<Object?, Object?>? raw = await _channel
          .invokeMapMethod<Object?, Object?>(
            'getAppIconsBatch',
            <String, Object>{'packageNames': missing},
          );
      if (raw == null || raw.isEmpty) return 0;

      int added = 0;
      raw.forEach((Object? key, Object? value) {
        final String packageName = (key ?? '').toString();
        if (packageName.isEmpty) return;
        if (value is Uint8List) {
          _setIcon(packageName, value);
          unawaited(_writeIconToDisk(packageName, value));
          added++;
        }
      });
      return added + diskAdded;
    } catch (_) {
      return diskAdded;
    }
  }

  static Uint8List? getCachedAppIcon(String packageName) {
    return _iconCache[packageName]?.bytes;
  }

  static ValueListenable<Uint8List?> iconListenable(String packageName) {
    final ValueNotifier<Uint8List?> notifier = _iconNotifiers.putIfAbsent(
      packageName,
      () => ValueNotifier<Uint8List?>(_iconCache[packageName]?.bytes),
    );
    if (notifier.value == null) {
      _hydrateSingleIconFromDisk(packageName);
    }
    return notifier;
  }

  static Future<List<LaunchableApp>> _loadAndroidApps() async {
    final List<dynamic> rawApps =
        await _channel.invokeMethod<List<dynamic>>('getLaunchableApps') ??
        <dynamic>[];

    return rawApps
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          final String packageName = (item['packageName'] ?? '').toString();
          final String label = (item['label'] ?? packageName).toString();
          return LaunchableApp(
            name: label,
            id: packageName,
            hint: packageName,
            searchKey: '$label $packageName'.toLowerCase(),
          );
        })
        .where((LaunchableApp app) => app.id.isNotEmpty)
        .toList();
  }

  static Future<Uint8List?> _fetchAppIcon(String packageName) async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        <String, Object>{'packageName': packageName},
      );
      if (bytes != null) {
        _setIcon(packageName, bytes);
        unawaited(_writeIconToDisk(packageName, bytes));
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static void _setIcon(String packageName, Uint8List? bytes) {
    _iconCache[packageName] = AppIconCacheEntry(bytes: bytes);
    final ValueNotifier<Uint8List?> notifier = _iconNotifiers.putIfAbsent(
      packageName,
      () => ValueNotifier<Uint8List?>(null),
    );
    notifier.value = bytes;
  }

  static Future<int> _hydrateIconsFromDisk(List<String> packageNames) async {
    int added = 0;
    for (final String packageName in packageNames) {
      if (_iconCache.containsKey(packageName)) continue;
      final Uint8List? bytes = await _readIconFromDisk(packageName);
      if (bytes == null) continue;
      _setIcon(packageName, bytes);
      added++;
    }
    return added;
  }

  static Future<void> _hydrateSingleIconFromDisk(String packageName) async {
    if (_diskReadInFlight.contains(packageName)) return;
    _diskReadInFlight.add(packageName);
    try {
      if (_iconCache.containsKey(packageName)) return;
      final Uint8List? bytes = await _readIconFromDisk(packageName);
      if (bytes == null) return;
      _setIcon(packageName, bytes);
    } finally {
      _diskReadInFlight.remove(packageName);
    }
  }

  static Future<String?> _ensureIconCacheDir() async {
    if (!kIsWeb && _iconCacheDir != null) return _iconCacheDir;
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      _iconCacheDir = await _channel.invokeMethod<String>('getIconCacheDir');
      return _iconCacheDir;
    } catch (_) {
      return null;
    }
  }

  static String _iconFileName(String packageName) {
    return base64UrlEncode(utf8.encode(packageName)).replaceAll('=', '');
  }

  static Future<Uint8List?> _readIconFromDisk(String packageName) async {
    final String? dir = await _ensureIconCacheDir();
    if (dir == null || dir.isEmpty) return null;
    final File file = File(
      '$dir${Platform.pathSeparator}${_iconFileName(packageName)}.bin',
    );
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeIconToDisk(
    String packageName,
    Uint8List bytes,
  ) async {
    final String? dir = await _ensureIconCacheDir();
    if (dir == null || dir.isEmpty) return;
    final Directory cacheDir = Directory(dir);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final File file = File(
      '$dir${Platform.pathSeparator}${_iconFileName(packageName)}.bin',
    );
    try {
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // Ignore IO errors; fallback remains in-memory cache.
    }
  }
}
