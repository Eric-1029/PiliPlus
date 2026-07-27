// Native Dart port of the rewrite policy from realzza/bilibili-accelerator
// v0.3.0 (MIT), commit 208cce947ed92ae8a6b0d03d930deb45a9dc39d5.
// Original work Copyright (c) 2026 realzza.
// See THIRD_PARTY_NOTICES.md for the complete MIT license notice.
//
// Browser interception and WebRTC-specific behavior are intentionally excluded.

enum CdnAcceleratorMode {
  badOnly,
  force,
  off;

  static CdnAcceleratorMode parse(Object? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => badOnly);
}

enum CdnSelectionMode {
  auto,
  fixed;

  static CdnSelectionMode parse(Object? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => auto);
}

enum McdnStrategy {
  proxyAll,
  proxyV1,
  replace;

  static McdnStrategy parse(Object? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => proxyAll);
}

enum CdnAcceleratorStatus { off, idle, probing, smooth, buffering }

final class CdnAcceleratorConfig {
  static const schemaVersion = 1;

  static const defaultCandidatePool = <String>[
    'upos-sz-mirrorcos.bilivideo.com',
    'upos-sz-mirrorali.bilivideo.com',
    'upos-sz-mirrorhw.bilivideo.com',
    'upos-tf-all-hw.bilivideo.com',
    'upos-tf-all-tx.bilivideo.com',
  ];

  static const allHosts = <String>[
    ...defaultCandidatePool,
    'upos-hz-mirrorakam.akamaized.net',
    'upos-sz-mirrorakam.akamaized.net',
    'upos-sz-mirroraliov.bilivideo.com',
    'upos-sz-mirrorcosov.bilivideo.com',
    'upos-sz-mirrorhwov.bilivideo.com',
  ];

  final bool enabled;
  final CdnAcceleratorMode mode;
  final CdnSelectionMode selection;
  final String fixedHost;
  final List<String> candidatePool;
  final McdnStrategy mcdnStrategy;
  final String proxyHost;
  final bool rewriteAkamai;
  final bool portHeuristic;
  final bool stallRecovery;

  const CdnAcceleratorConfig({
    this.enabled = true,
    this.mode = CdnAcceleratorMode.badOnly,
    this.selection = CdnSelectionMode.auto,
    this.fixedHost = 'upos-sz-mirrorcos.bilivideo.com',
    this.candidatePool = defaultCandidatePool,
    this.mcdnStrategy = McdnStrategy.proxyAll,
    this.proxyHost = 'proxy-tf-all-ws.bilivideo.com',
    this.rewriteAkamai = false,
    this.portHeuristic = true,
    this.stallRecovery = true,
  });

  factory CdnAcceleratorConfig.fromJson(Object? value) {
    if (value is! Map) return const CdnAcceleratorConfig();
    final candidates = switch (value['candidatePool']) {
      final List list =>
        list
            .whereType<String>()
            .map(CdnAcceleratorCore.cleanHost)
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList(),
      _ => const <String>[],
    };
    final fixedHost = CdnAcceleratorCore.cleanHost(
      value['fixedHost']?.toString(),
    );
    final proxyHost = CdnAcceleratorCore.cleanHost(
      value['proxyHost']?.toString(),
    );
    return CdnAcceleratorConfig(
      enabled: value['enabled'] is bool ? value['enabled'] as bool : true,
      mode: CdnAcceleratorMode.parse(value['mode']),
      selection: CdnSelectionMode.parse(value['selection']),
      fixedHost: fixedHost.isEmpty
          ? 'upos-sz-mirrorcos.bilivideo.com'
          : fixedHost,
      candidatePool: candidates.isEmpty ? defaultCandidatePool : candidates,
      mcdnStrategy: McdnStrategy.parse(value['mcdnStrategy']),
      proxyHost: proxyHost.isEmpty
          ? 'proxy-tf-all-ws.bilivideo.com'
          : proxyHost,
      rewriteAkamai: value['rewriteAkamai'] == true,
      portHeuristic: value['portHeuristic'] is bool
          ? value['portHeuristic'] as bool
          : true,
      stallRecovery: value['stallRecovery'] is bool
          ? value['stallRecovery'] as bool
          : true,
    );
  }

  CdnAcceleratorConfig copyWith({
    bool? enabled,
    CdnAcceleratorMode? mode,
    CdnSelectionMode? selection,
    String? fixedHost,
    List<String>? candidatePool,
    McdnStrategy? mcdnStrategy,
    String? proxyHost,
    bool? rewriteAkamai,
    bool? portHeuristic,
    bool? stallRecovery,
  }) => CdnAcceleratorConfig(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    selection: selection ?? this.selection,
    fixedHost: fixedHost ?? this.fixedHost,
    candidatePool: candidatePool ?? this.candidatePool,
    mcdnStrategy: mcdnStrategy ?? this.mcdnStrategy,
    proxyHost: proxyHost ?? this.proxyHost,
    rewriteAkamai: rewriteAkamai ?? this.rewriteAkamai,
    portHeuristic: portHeuristic ?? this.portHeuristic,
    stallRecovery: stallRecovery ?? this.stallRecovery,
  );

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'enabled': enabled,
    'mode': mode.name,
    'selection': selection.name,
    'fixedHost': fixedHost,
    'candidatePool': candidatePool,
    'mcdnStrategy': mcdnStrategy.name,
    'proxyHost': proxyHost,
    'rewriteAkamai': rewriteAkamai,
    'portHeuristic': portHeuristic,
    'stallRecovery': stallRecovery,
  };
}

final class CdnVerdict {
  final String host;
  final String kind;
  final bool isPcdn;
  final bool isMcdn;
  final bool isAkamai;
  final bool isSlow;
  final String? schedulerSource;

  const CdnVerdict({
    required this.host,
    required this.kind,
    required this.isPcdn,
    required this.isMcdn,
    required this.isAkamai,
    required this.isSlow,
    this.schedulerSource,
  });
}

final class CdnRewrite {
  final String original;
  final String url;
  final String reason;
  final String? targetHost;

  const CdnRewrite({
    required this.original,
    required this.url,
    required this.reason,
    this.targetHost,
  });

  bool get changed => original != url;
}

final class CdnResolution {
  final String primaryUrl;
  final List<String> fallbackUrls;
  final String reason;
  final String? selectedHost;

  const CdnResolution({
    required this.primaryUrl,
    this.fallbackUrls = const [],
    required this.reason,
    this.selectedHost,
  });

  Iterable<String> get urls sync* {
    yield primaryUrl;
    yield* fallbackUrls;
  }
}

final class CdnProbeResult {
  final String host;
  final int? ttfbMs;
  final bool ok;

  const CdnProbeResult({required this.host, this.ttfbMs, required this.ok});

  Map<String, Object?> toJson() => {'host': host, 'ttfbMs': ttfbMs, 'ok': ok};
}

abstract final class CdnAcceleratorCore {
  static final _ip = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');
  static final _xyMcdn = RegExp(
    r'^xy(?:\d+x){3}\d+xy\.mcdn\.bilivideo\.(?:cn|com|net)$',
    caseSensitive: false,
  );
  static final _mediaExt = RegExp(
    r'\.(?:m4s|mp4|flv|m3u8)(?:$|[?#])',
    caseSensitive: false,
  );
  static const _p2pSuffixes = <String>[
    '.szbdyd.com',
    '.mountaintoys.cn',
    '.nexusedgeio.com',
    '.ahdohpiechei.com',
  ];

  static String cleanHost(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    return parsed?.host.isNotEmpty == true
        ? parsed!.host
        : raw
              .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
              .split('/')
              .first;
  }

  static bool isMediaUrl(Uri uri) =>
      _mediaExt.hasMatch('${uri.path}?${uri.query}') ||
      uri.path.startsWith('/upgcxcode/') ||
      uri.path.startsWith('/v1/resource/');

  static bool isLiveMediaUrl(Uri uri) => uri.path.contains('/live-bvc/');

  static bool _isMcdn(String host) => RegExp(
    r'\.mcdn\.bilivideo\.(?:cn|com|net)$',
    caseSensitive: false,
  ).hasMatch(host);

  static bool _isKnownP2p(String host) {
    if (host == 'upos-sz-mirror14b.bilivideo.com') return true;
    if (_p2pSuffixes.any(host.endsWith)) return true;
    final first = host.split('.').first;
    return first.startsWith('upos-') && first.contains('302');
  }

  static CdnVerdict classify(Uri uri, CdnAcceleratorConfig config) {
    final host = uri.host.toLowerCase();
    final scheduler = host.endsWith('.szbdyd.com')
        ? cleanHost(uri.queryParameters['xy_usource'])
        : '';
    final mcdn = _isMcdn(host);
    final akamai = host.endsWith('.akamaized.net');
    final nonDefaultPort = uri.hasPort && uri.port != 80 && uri.port != 443;
    final queryMcdn = uri.queryParameters['os'] == 'mcdn';
    final isPcdn =
        _ip.hasMatch(host) ||
        _xyMcdn.hasMatch(host) ||
        (config.portHeuristic && nonDefaultPort) ||
        queryMcdn ||
        _isKnownP2p(host);
    final overseas =
        host.contains('mirroraliov') ||
        host.contains('mirrorcosov') ||
        host.contains('mirrorhwov');
    final kind = scheduler.isNotEmpty || host.endsWith('.szbdyd.com')
        ? 'scheduler'
        : mcdn
        ? 'mcdn'
        : isPcdn
        ? 'pcdn'
        : akamai
        ? 'akamai'
        : host.startsWith('upos-') || host.endsWith('.bilivideo.com')
        ? 'upos'
        : 'unknown';
    return CdnVerdict(
      host: host,
      kind: kind,
      isPcdn: isPcdn,
      isMcdn: mcdn,
      isAkamai: akamai,
      isSlow: isPcdn || overseas || (config.rewriteAkamai && akamai),
      schedulerSource: scheduler.isEmpty ? null : scheduler,
    );
  }

  static bool isSlowLiveHost(
    String hostValue,
    String extra,
    CdnAcceleratorConfig config,
  ) {
    final uri = Uri.tryParse(
      hostValue.contains('://') ? hostValue : 'https://$hostValue',
    );
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return _ip.hasMatch(host) ||
        _xyMcdn.hasMatch(host) ||
        _isMcdn(host) ||
        _isKnownP2p(host) ||
        (config.portHeuristic &&
            uri.hasPort &&
            uri.port != 80 &&
            uri.port != 443) ||
        RegExp(
          r'(?:^|[?&])os=mcdn(?:&|$)',
          caseSensitive: false,
        ).hasMatch(extra);
  }

  static CdnRewrite rewrite(
    String value,
    CdnAcceleratorConfig config, {
    List<String> ranking = const [],
    String? avoidHost,
  }) {
    final uri = Uri.tryParse(value.startsWith('//') ? 'https:$value' : value);
    if (!config.enabled ||
        config.mode == CdnAcceleratorMode.off ||
        uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        !isMediaUrl(uri) ||
        cleanHost(config.proxyHost) == uri.host) {
      return CdnRewrite(original: value, url: value, reason: 'ignored');
    }
    if (isLiveMediaUrl(uri)) {
      return CdnRewrite(original: value, url: value, reason: 'live-skip');
    }

    final verdict = classify(uri, config);
    if (verdict.schedulerSource case final source?) {
      final rewritten = _replaceHost(uri, source);
      return CdnRewrite(
        original: value,
        url: rewritten,
        reason: 'szbdyd-source',
        targetHost: source,
      );
    }
    final proxy =
        verdict.isMcdn &&
        (config.mcdnStrategy == McdnStrategy.proxyAll ||
            config.mcdnStrategy == McdnStrategy.proxyV1 &&
                uri.path.startsWith('/v1/resource/'));
    if (proxy) {
      final rewritten = Uri.https(config.proxyHost, '/', {
        'url': uri.toString(),
      });
      return CdnRewrite(
        original: value,
        url: rewritten.toString(),
        reason: 'mcdn-proxy',
        targetHost: config.proxyHost,
      );
    }

    final force =
        config.mode == CdnAcceleratorMode.force ||
        avoidHost != null && uri.host == avoidHost;
    final biliCdn =
        uri.host.endsWith('.bilivideo.com') ||
        uri.host.endsWith('.bilivideo.cn') ||
        uri.host.endsWith('.bilivideo.net') ||
        uri.host.endsWith('.akamaized.net');
    if (verdict.isSlow || verdict.isMcdn || force && biliCdn) {
      final target = selectTarget(config, ranking, avoidHost: avoidHost);
      return CdnRewrite(
        original: value,
        url: _replaceHost(uri, target),
        reason: verdict.isPcdn
            ? 'pcdn-host'
            : verdict.isMcdn
            ? 'mcdn-host'
            : 'cdn-host',
        targetHost: target,
      );
    }
    return CdnRewrite(original: value, url: value, reason: 'ok');
  }

  static CdnResolution resolve(
    Iterable<String> values,
    CdnAcceleratorConfig config, {
    List<String> ranking = const [],
    String? avoidHost,
  }) {
    final source = values.where((e) => e.isNotEmpty).toList();
    if (source.isEmpty) {
      return const CdnResolution(primaryUrl: '', reason: 'empty');
    }
    final first = rewrite(
      source.first,
      config,
      ranking: ranking,
      avoidHost: avoidHost,
    );
    final alternatives = <String>[
      for (final item in source.skip(1))
        rewrite(item, config, ranking: ranking, avoidHost: avoidHost).url,
      ...alternativesFor(
        first.url,
        ranking.isEmpty ? config.candidatePool : ranking,
      ),
    ];
    final unique = <String>[];
    for (final url in alternatives) {
      if (url != first.url && !unique.contains(url)) unique.add(url);
      if (unique.length == 8) break;
    }
    return CdnResolution(
      primaryUrl: first.url,
      fallbackUrls: unique,
      reason: first.reason,
      selectedHost: Uri.tryParse(first.url)?.host,
    );
  }

  static String selectTarget(
    CdnAcceleratorConfig config,
    List<String> ranking, {
    String? avoidHost,
  }) {
    if (config.selection == CdnSelectionMode.fixed) {
      final fixed = cleanHost(config.fixedHost);
      return fixed.isEmpty
          ? CdnAcceleratorConfig.defaultCandidatePool.first
          : fixed;
    }
    final pool = ranking.isEmpty ? config.candidatePool : ranking;
    return pool
        .map(cleanHost)
        .firstWhere(
          (host) => host.isNotEmpty && host != avoidHost,
          orElse: () => CdnAcceleratorConfig.defaultCandidatePool.first,
        );
  }

  static List<String> alternativesFor(String value, Iterable<String> hosts) {
    final uri = Uri.tryParse(value);
    if (uri == null || !isMediaUrl(uri) || isLiveMediaUrl(uri)) return const [];
    return hosts
        .map(cleanHost)
        .where((host) => host.isNotEmpty && host != uri.host)
        .toSet()
        .map((host) => _replaceHost(uri, host))
        .toList();
  }

  static String replaceHost(String value, String host) {
    final uri = Uri.tryParse(value);
    return uri == null ? value : _replaceHost(uri, cleanHost(host));
  }

  static List<CdnProbeResult> rankSamples(Iterable<CdnProbeResult> samples) {
    final result = samples.toList()
      ..sort((a, b) {
        if (a.ok != b.ok) return a.ok ? -1 : 1;
        if (!a.ok) return 0;
        return (a.ttfbMs ?? 1 << 30).compareTo(b.ttfbMs ?? 1 << 30);
      });
    return result;
  }

  static double throughputMbps(int bytes, int durationMs) =>
      bytes <= 0 || durationMs <= 0
      ? 0
      : (bytes * 8 / 1000000) / (durationMs / 1000);

  static String hostOf(String value) => Uri.tryParse(value)?.authority ?? '';

  static String _replaceHost(Uri uri, String hostValue) {
    final target = Uri.tryParse(
      hostValue.contains('://') ? hostValue : 'https://$hostValue',
    );
    final host = target?.host.isNotEmpty == true ? target!.host : hostValue;
    final port = target?.hasPort == true ? target!.port : null;
    return Uri(
      scheme: 'https',
      userInfo: uri.userInfo,
      host: host,
      port: port,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }
}
