import 'package:PiliPlus/models/common/video/cdn_accelerator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = CdnAcceleratorConfig();
  const sample =
      'https://xy153x35x231x78xy.mcdn.bilivideo.cn:8082/v1/resource/'
      'video.m4s?os=mcdn&deadline=1';

  group('config', () {
    test('defaults to enabled automatic conservative mode', () {
      expect(config.enabled, isTrue);
      expect(config.mode, CdnAcceleratorMode.badOnly);
      expect(config.selection, CdnSelectionMode.auto);
      expect(config.mcdnStrategy, McdnStrategy.proxyAll);
      expect(config.portHeuristic, isTrue);
      expect(config.stallRecovery, isTrue);
    });

    test('invalid enum values fall back to defaults', () {
      final parsed = CdnAcceleratorConfig.fromJson({
        'mode': 'invalid',
        'selection': 'invalid',
        'mcdnStrategy': 'invalid',
        'candidatePool': const [],
      });
      expect(parsed.mode, CdnAcceleratorMode.badOnly);
      expect(parsed.selection, CdnSelectionMode.auto);
      expect(parsed.mcdnStrategy, McdnStrategy.proxyAll);
      expect(parsed.candidatePool, isNotEmpty);
    });
  });

  group('classification', () {
    test('flags odd ports and os=mcdn as PCDN', () {
      final verdict = CdnAcceleratorCore.classify(Uri.parse(sample), config);
      expect(verdict.isPcdn, isTrue);
      expect(verdict.isMcdn, isTrue);
    });

    test('detects renamed and redirect PCDN families', () {
      const hosts = [
        'https://a.edge.mountaintoys.cn:9000/upgcxcode/a.m4s',
        'https://a.nexusedgeio.com/upgcxcode/a.m4s',
        'https://a.ahdohpiechei.com/upgcxcode/a.m4s',
        'https://upos-sz-302ppio.bilivideo.com/upgcxcode/a.m4s',
        'https://upos-sz-mirror14b.bilivideo.com/upgcxcode/a.m4s',
      ];
      for (final value in hosts) {
        expect(
          CdnAcceleratorCore.classify(Uri.parse(value), config).isPcdn,
          isTrue,
          reason: value,
        );
      }
    });

    test('port heuristic can be disabled', () {
      final verdict = CdnAcceleratorCore.classify(
        Uri.parse('https://example.com:9000/upgcxcode/a.m4s'),
        config.copyWith(portHeuristic: false),
      );
      expect(verdict.isPcdn, isFalse);
    });

    test('healthy UPOS remains healthy', () {
      final verdict = CdnAcceleratorCore.classify(
        Uri.parse('https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/a.m4s'),
        config,
      );
      expect(verdict.kind, 'upos');
      expect(verdict.isSlow, isFalse);
    });
  });

  group('rewrite', () {
    test('proxies MCDN by default', () {
      final result = CdnAcceleratorCore.rewrite(sample, config);
      expect(result.reason, 'mcdn-proxy');
      expect(Uri.parse(result.url).host, config.proxyHost);
      expect(Uri.parse(result.url).queryParameters['url'], sample);
    });

    test('can replace MCDN host', () {
      final result = CdnAcceleratorCore.rewrite(
        sample,
        config.copyWith(mcdnStrategy: McdnStrategy.replace),
      );
      expect(Uri.parse(result.url).host, config.candidatePool.first);
      expect(result.reason, 'pcdn-host');
    });

    test('proxy-v1 only proxies resource path', () {
      final proxyV1 = config.copyWith(mcdnStrategy: McdnStrategy.proxyV1);
      expect(CdnAcceleratorCore.rewrite(sample, proxyV1).reason, 'mcdn-proxy');
      final upgc = sample.replaceFirst('/v1/resource/', '/upgcxcode/');
      expect(CdnAcceleratorCore.rewrite(upgc, proxyV1).reason, 'pcdn-host');
    });

    test('unwraps szbdyd scheduler source', () {
      const value =
          'https://a.szbdyd.com/upgcxcode/a.m4s'
          '?xy_usource=upos-tf-all-hw.bilivideo.com';
      final result = CdnAcceleratorCore.rewrite(value, config);
      expect(result.reason, 'szbdyd-source');
      expect(Uri.parse(result.url).host, 'upos-tf-all-hw.bilivideo.com');
    });

    test('force mode switches healthy CDN', () {
      const value = 'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/a.m4s';
      final result = CdnAcceleratorCore.rewrite(
        value,
        config.copyWith(mode: CdnAcceleratorMode.force),
      );
      expect(Uri.parse(result.url).host, config.candidatePool.first);
    });

    test('live media URL is never VOD-swapped', () {
      const value = 'https://xy1x2x3x4xy.mcdn.bilivideo.cn:8080/live-bvc/a.flv';
      expect(CdnAcceleratorCore.rewrite(value, config).reason, 'live-skip');
      expect(
        CdnAcceleratorCore.alternativesFor(value, config.candidatePool),
        isEmpty,
      );
    });
  });

  group('fallbacks and live', () {
    test('resolution adds unique host alternatives', () {
      const value = 'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/a.m4s';
      final result = CdnAcceleratorCore.resolve([value], config);
      expect(result.primaryUrl, value);
      expect(result.fallbackUrls, isNotEmpty);
      expect(result.urls.toSet().length, result.urls.length);
    });

    test('detects slow live hosts', () {
      expect(
        CdnAcceleratorCore.isSlowLiveHost(
          'https://a.edge.mountaintoys.cn:9000',
          '',
          config,
        ),
        isTrue,
      );
      expect(
        CdnAcceleratorCore.isSlowLiveHost(
          'https://d1--cn-gotcha204.bilivideo.com',
          '',
          config,
        ),
        isFalse,
      );
    });
  });

  test('ranking orders healthy hosts by TTFB', () {
    final ranked = CdnAcceleratorCore.rankSamples(const [
      CdnProbeResult(host: 'failed', ok: false),
      CdnProbeResult(host: 'slow', ttfbMs: 200, ok: true),
      CdnProbeResult(host: 'fast', ttfbMs: 20, ok: true),
    ]);
    expect(ranked.map((e) => e.host), ['fast', 'slow', 'failed']);
  });

  test('throughput and diagnostics host helpers do not retain query', () {
    expect(CdnAcceleratorCore.throughputMbps(1000000, 1000), closeTo(8, 0.001));
    expect(
      CdnAcceleratorCore.hostOf('https://example.com:8443/a.m4s?token=secret'),
      'example.com:8443',
    );
  });
}
