import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/models/common/video/cdn_accelerator.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class CdnAcceleratorService extends ChangeNotifier {
  CdnAcceleratorService._();

  static final instance = CdnAcceleratorService._();
  static const _rankTtl = Duration(hours: 6);
  static const _probeTimeout = Duration(seconds: 4);

  CdnAcceleratorConfig _config = const CdnAcceleratorConfig();
  CdnAcceleratorConfig get config => _config;

  CdnAcceleratorStatus status = CdnAcceleratorStatus.idle;
  List<CdnProbeResult> probeResults = const [];
  DateTime? probedAt;
  String? currentHost;
  int rewriteCount = 0;
  int stallCount = 0;
  int recoveryCount = 0;
  double currentMbps = 0;
  double peakMbps = 0;
  double bufferAhead = 0;
  final List<double> speedHistory = [];
  final List<Map<String, Object?>> _recentRewrites = [];
  String? _lastSampleUrl;

  Future<void>? _activeProbe;

  bool get isSupported => Platform.isAndroid;
  List<String> get ranking =>
      probeResults.where((e) => e.ok).map((e) => e.host).toList();

  Future<void> initialize() async {
    await _migrateLegacySettings();
    _config = CdnAcceleratorConfig.fromJson(
      GStorage.setting.get(SettingBoxKey.cdnAcceleratorConfig),
    );
    _restoreStats();
    _restoreRanking();
    status = !_config.enabled || _config.mode == CdnAcceleratorMode.off
        ? CdnAcceleratorStatus.off
        : CdnAcceleratorStatus.idle;
    notifyListeners();
  }

  Future<void> _migrateLegacySettings() async {
    if (GStorage.setting.get(SettingBoxKey.cdnAcceleratorMigrated) == true) {
      return;
    }
    await Future.wait([
      GStorage.setting.delete(SettingBoxKey.CDNService),
      GStorage.setting.delete(SettingBoxKey.liveCdnUrl),
      GStorage.setting.delete(SettingBoxKey.cdnSpeedTest),
      GStorage.setting.delete(SettingBoxKey.disableAudioCDN),
    ]);
    await GStorage.setting.put(
      SettingBoxKey.cdnAcceleratorConfig,
      const CdnAcceleratorConfig().toJson(),
    );
    await GStorage.setting.put(SettingBoxKey.cdnAcceleratorMigrated, true);
  }

  Future<void> updateConfig(CdnAcceleratorConfig next) async {
    _config = CdnAcceleratorConfig.fromJson(next.toJson());
    status = !_config.enabled || _config.mode == CdnAcceleratorMode.off
        ? CdnAcceleratorStatus.off
        : CdnAcceleratorStatus.idle;
    await GStorage.setting.put(
      SettingBoxKey.cdnAcceleratorConfig,
      _config.toJson(),
    );
    notifyListeners();
  }

  CdnResolution resolve(
    Iterable<String> urls, {
    String? avoidHost,
    bool probe = true,
  }) {
    final source = urls.where((e) => e.isNotEmpty).toList();
    if (source.isEmpty) {
      return const CdnResolution(primaryUrl: '', reason: 'empty');
    }
    if (!isSupported) {
      return CdnResolution(primaryUrl: source.first, reason: 'unsupported');
    }
    final resolution = CdnAcceleratorCore.resolve(
      source,
      _config,
      ranking: ranking,
      avoidHost: avoidHost,
    );
    currentHost = resolution.selectedHost;
    if (Uri.tryParse(source.first) case final Uri uri
        when CdnAcceleratorCore.isMediaUrl(uri)) {
      _lastSampleUrl = source.first;
    }
    if (resolution.primaryUrl != source.first) {
      _recordRewrite(source.first, resolution.primaryUrl, resolution.reason);
    }
    if (probe && _config.selection == CdnSelectionMode.auto) {
      unawaited(probeIfNeeded(source.first));
    }
    return resolution;
  }

  List<int> usableLiveIndexes(List<({String host, String extra})> sources) {
    if (!isSupported ||
        !_config.enabled ||
        _config.mode == CdnAcceleratorMode.off) {
      return List.generate(sources.length, (index) => index);
    }
    final kept = <int>[
      for (final (index, source) in sources.indexed)
        if (!CdnAcceleratorCore.isSlowLiveHost(
          source.host,
          source.extra,
          _config,
        ))
          index,
    ];
    return kept.isEmpty
        ? List.generate(sources.length, (index) => index)
        : kept;
  }

  Future<void> probeIfNeeded(String sampleUrl) {
    if (!isSupported ||
        !_config.enabled ||
        _config.selection != CdnSelectionMode.auto ||
        probeResults.isNotEmpty ||
        _activeProbe != null) {
      return _activeProbe ?? Future.value();
    }
    return _activeProbe = _probe(sampleUrl).whenComplete(() {
      _activeProbe = null;
    });
  }

  Future<void> reprobe(String sampleUrl) async {
    if (!isSupported || sampleUrl.isEmpty) return;
    probeResults = const [];
    probedAt = null;
    await GStorage.localCache.delete(_rankingKey);
    await (_activeProbe ??= _probe(sampleUrl).whenComplete(() {
      _activeProbe = null;
    }));
  }

  Future<bool> reprobeLast() async {
    final sample = _lastSampleUrl;
    if (sample == null) return false;
    await reprobe(sample);
    return true;
  }

  Future<void> _probe(String sampleUrl) async {
    final uri = Uri.tryParse(sampleUrl);
    if (uri == null || !CdnAcceleratorCore.isMediaUrl(uri)) return;
    status = CdnAcceleratorStatus.probing;
    notifyListeners();
    final hosts = _config.candidatePool.take(5).toList();
    final results = await Future.wait(
      hosts.map((host) => _probeHost(host, sampleUrl)),
    );
    probeResults = CdnAcceleratorCore.rankSamples(results);
    probedAt = DateTime.now();
    status = CdnAcceleratorStatus.smooth;
    await GStorage.localCache.put(_rankingKey, {
      'at': probedAt!.millisecondsSinceEpoch,
      'results': probeResults.map((e) => e.toJson()).toList(),
    });
    notifyListeners();
  }

  Future<CdnProbeResult> _probeHost(String host, String sampleUrl) async {
    if (Uri.tryParse(sampleUrl) == null) {
      return CdnProbeResult(host: host, ok: false);
    }
    final target = CdnAcceleratorCore.replaceHost(sampleUrl, host);
    final dio = Dio(
      BaseOptions(
        connectTimeout: _probeTimeout,
        receiveTimeout: _probeTimeout,
        headers: {'user-agent': BrowserUa.pc, 'referer': HttpString.baseUrl},
      ),
    );
    final token = CancelToken();
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<ResponseBody>(
        target,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );
      stopwatch.stop();
      final ok =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
      await response.data?.stream.listen((_) {}).cancel();
      return CdnProbeResult(
        host: host,
        ttfbMs: ok ? stopwatch.elapsedMilliseconds : null,
        ok: ok,
      );
    } catch (_) {
      return CdnProbeResult(host: host, ok: false);
    } finally {
      token.cancel();
      dio.close(force: true);
    }
  }

  String rotateTarget(String? stallingHost) {
    final host = CdnAcceleratorCore.selectTarget(
      _config,
      ranking,
      avoidHost: stallingHost,
    );
    currentHost = host;
    return host;
  }

  void reportBuffering() {
    stallCount += 1;
    status = CdnAcceleratorStatus.buffering;
    _persistStats();
    notifyListeners();
  }

  void reportRecovery() {
    recoveryCount += 1;
    _persistStats();
    notifyListeners();
  }

  void reportPlaying() {
    if (_config.enabled && status == CdnAcceleratorStatus.buffering) {
      status = CdnAcceleratorStatus.smooth;
      notifyListeners();
    }
  }

  void recordSpeed({required double mbps, required double bufferedSeconds}) {
    currentMbps = mbps.isFinite && mbps > 0 ? mbps : 0;
    if (currentMbps > peakMbps) peakMbps = currentMbps;
    bufferAhead = bufferedSeconds < 0 ? 0 : bufferedSeconds;
    speedHistory.add(currentMbps);
    if (speedHistory.length > 60) speedHistory.removeAt(0);
    notifyListeners();
  }

  Map<String, Object?> diagnostics() => {
    'version': 'native-1',
    'region': DateTime.now().timeZoneName,
    'config': _config.toJson(),
    'status': status.name,
    'counters': {
      'rewrites': rewriteCount,
      'stalls': stallCount,
      'recoveries': recoveryCount,
    },
    'ranking': probeResults.map((e) => e.toJson()).toList(),
    'probedAt': probedAt?.toIso8601String(),
    'currentHost': currentHost,
    'recentRewrites': _recentRewrites.take(15).toList(),
  };

  void _recordRewrite(String from, String to, String reason) {
    rewriteCount += 1;
    _recentRewrites.insert(0, {
      'at': DateTime.now().toIso8601String(),
      'reason': reason,
      'fromHost': CdnAcceleratorCore.hostOf(from),
      'toHost': CdnAcceleratorCore.hostOf(to),
    });
    if (_recentRewrites.length > 50) _recentRewrites.removeLast();
    if (status == CdnAcceleratorStatus.idle) {
      status = CdnAcceleratorStatus.smooth;
    }
    _persistStats();
    notifyListeners();
  }

  String get _rankingKey =>
      '${LocalCacheKey.cdnAcceleratorRankPrefix}'
      '${DateTime.now().timeZoneName}|${Platform.localeName}';

  void _restoreRanking() {
    final stored = GStorage.localCache.get(_rankingKey);
    if (stored is! Map || stored['at'] is! int || stored['results'] is! List) {
      return;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(stored['at'] as int);
    if (DateTime.now().difference(at) > _rankTtl) return;
    probeResults = (stored['results'] as List)
        .whereType<Map>()
        .map(
          (e) => CdnProbeResult(
            host: e['host']?.toString() ?? '',
            ttfbMs: e['ttfbMs'] as int?,
            ok: e['ok'] == true,
          ),
        )
        .where((e) => e.host.isNotEmpty)
        .toList();
    probedAt = at;
  }

  void _restoreStats() {
    final stored = GStorage.localCache.get(LocalCacheKey.cdnAcceleratorStats);
    if (stored is! Map) return;
    rewriteCount = stored['rewrites'] as int? ?? 0;
    stallCount = stored['stalls'] as int? ?? 0;
    recoveryCount = stored['recoveries'] as int? ?? 0;
  }

  void _persistStats() {
    unawaited(
      GStorage.localCache.put(LocalCacheKey.cdnAcceleratorStats, {
        'rewrites': rewriteCount,
        'stalls': stallCount,
        'recoveries': recoveryCount,
      }),
    );
  }
}
