import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/launchable_app.dart';

class AppLauncherService {
  static const MethodChannel _channel = MethodChannel('quick_box/launcher');
  static List<LaunchableApp>? _cachedApps;
  static final Map<String, AppIconCacheEntry> _iconCache =
      <String, AppIconCacheEntry>{};
  static final Map<String, Future<Uint8List?>> _iconInFlight =
      <String, Future<Uint8List?>>{};

  static Future<List<LaunchableApp>> getApps({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _cachedApps = null;
      _iconCache.clear();
      _iconInFlight.clear();
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

    final Future<Uint8List?>? running = _iconInFlight[packageName];
    if (running != null) return running;

    final Future<Uint8List?> task = _fetchAppIcon(packageName);
    _iconInFlight[packageName] = task;

    try {
      final Uint8List? bytes = await task;
      _iconCache[packageName] = AppIconCacheEntry(bytes: bytes);
      return bytes;
    } finally {
      _iconInFlight.remove(packageName);
    }
  }

  static Future<int> fetchIconsBatch(List<String> packageNames) async {
    if (kIsWeb || !Platform.isAndroid || packageNames.isEmpty) return 0;

    final List<String> missing = packageNames
        .where((String packageName) => !_iconCache.containsKey(packageName))
        .toSet()
        .toList();
    if (missing.isEmpty) return 0;

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
          _iconCache[packageName] = AppIconCacheEntry(bytes: value);
          added++;
        }
      });
      return added;
    } catch (_) {
      return 0;
    }
  }

  static Uint8List? getCachedAppIcon(String packageName) {
    return _iconCache[packageName]?.bytes;
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
      return await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        <String, Object>{'packageName': packageName},
      );
    } catch (_) {
      return null;
    }
  }
}
