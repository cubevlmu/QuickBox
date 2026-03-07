/*
 * @Author: cubevlmu khfahqp@gmail.com
 * @LastEditors: cubevlmu khfahqp@gmail.com
 * Copyright (c) 2026 by FlybirdGames, All Rights Reserved. 
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/launchable_app.dart';
import '../services/app_launcher_service.dart';

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({super.key});

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  static const double _rowHeight = 68;
  static const int _iconBatchSize = 8;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<LaunchableApp> _apps = <LaunchableApp>[];
  String _searchKeyword = '';
  List<LaunchableApp> _filteredApps = <LaunchableApp>[];
  bool _loading = true;
  String? _error;
  Timer? _iconLoadDebounce;
  bool _iconBatchLoading = false;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApps();
    });
  }

  @override
  void dispose() {
    _iconLoadDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchKeyword = _searchController.text.trim().toLowerCase();
      _filteredApps = _buildFilteredApps(_searchKeyword);
    });
    _scheduleVisibleIconLoad();
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<LaunchableApp> apps = await AppLauncherService.getApps(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _filteredApps = _buildFilteredApps(_searchKeyword);
        _loading = false;
      });
      _scheduleVisibleIconLoad(immediate: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _launchApp(LaunchableApp app) async {
    final bool ok = await AppLauncherService.launch(app);
    if (!mounted) return;

    if (ok) {
      await SystemNavigator.pop();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('无法启动: ${app.name}')));
  }

  List<LaunchableApp> _buildFilteredApps(String keyword) {
    if (keyword.isEmpty) return _apps;
    return _apps
        .where((LaunchableApp app) => app.searchKey.contains(keyword))
        .toList();
  }

  void _applySearchAction() {
    _searchFocusNode.unfocus();
    _scheduleVisibleIconLoad(immediate: true);
  }

  void _scheduleVisibleIconLoad({bool immediate = false}) {
    _iconLoadDebounce?.cancel();
    _iconLoadDebounce = Timer(
      Duration(milliseconds: immediate ? 0 : 120),
      _loadVisibleIconsBatch,
    );
  }

  Future<void> _loadVisibleIconsBatch() async {
    if (!mounted ||
        _loading ||
        _filteredApps.isEmpty ||
        _iconBatchLoading ||
        _isUserScrolling) {
      return;
    }
    if (!_scrollController.hasClients) return;

    final double offset = _scrollController.offset;
    final double viewport = _scrollController.position.viewportDimension;
    final int start = (offset / _rowHeight).floor().clamp(
      0,
      _filteredApps.length - 1,
    );
    final int end = ((offset + viewport) / _rowHeight).ceil().clamp(
      0,
      _filteredApps.length,
    );
    final int padStart = (start - 8).clamp(0, _filteredApps.length);
    final int padEnd = (end + 16).clamp(0, _filteredApps.length);

    final List<String> packageNames = <String>[];
    for (int i = padStart; i < padEnd; i++) {
      final String packageName = _filteredApps[i].id;
      if (AppLauncherService.getCachedAppIcon(packageName) == null) {
        packageNames.add(packageName);
      }
      if (packageNames.length >= _iconBatchSize) break;
    }
    if (packageNames.isEmpty) return;

    _iconBatchLoading = true;
    try {
      await AppLauncherService.fetchIconsBatch(packageNames);
    } finally {
      _iconBatchLoading = false;
    }

    if (mounted && !_isUserScrolling) {
      _scheduleVisibleIconLoad();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applySearchAction(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: "搜索...",
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _loadApps(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }

    if (_apps.isEmpty) {
      return const Center(child: Text('当前平台暂无可用应用列表'));
    }

    if (_filteredApps.isEmpty) {
      return const Center(child: Text('没有匹配结果'));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleVisibleIconLoad();
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification) {
          _isUserScrolling = true;
          _iconLoadDebounce?.cancel();
        } else if (notification is ScrollEndNotification) {
          _isUserScrolling = false;
          _scheduleVisibleIconLoad(immediate: true);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _filteredApps.length,
        itemExtent: _rowHeight,
        addAutomaticKeepAlives: false,
        itemBuilder: (BuildContext context, int index) {
          final LaunchableApp app = _filteredApps[index];
          return _AppRow(
            key: ValueKey<String>(app.id),
            app: app,
            onTap: () => _launchApp(app),
          );
        },
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({super.key, required this.app, required this.onTap});

  final LaunchableApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
      child: ListTile(
        dense: true,
        leading: ValueListenableBuilder<Uint8List?>(
          valueListenable: AppLauncherService.iconListenable(app.id),
          builder: (BuildContext context, Uint8List? iconBytes, Widget? child) {
            return _buildLeadingIcon(iconBytes);
          },
        ),
        title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(app.hint, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeadingIcon(Uint8List? iconBytes) {
    if (iconBytes == null || iconBytes.isEmpty) {
      return const Icon(Icons.android, size: 28);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: RepaintBoundary(
        child: Image.memory(
          iconBytes,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 60,
          cacheHeight: 60,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
