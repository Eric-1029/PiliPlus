import 'dart:convert';
import 'dart:math' as math;

import 'package:PiliPlus/models/common/video/cdn_accelerator.dart';
import 'package:PiliPlus/services/cdn_accelerator_service.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class CdnAcceleratorPage extends StatelessWidget {
  const CdnAcceleratorPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('播放加速')),
    body: const SafeArea(child: CdnAcceleratorPanel()),
  );
}

class CdnAcceleratorPanel extends StatelessWidget {
  final Future<void> Function()? onBoost;

  const CdnAcceleratorPanel({super.key, this.onBoost});

  @override
  Widget build(BuildContext context) {
    final service = CdnAcceleratorService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final config = service.config;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _StatusCard(service: service),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: const Text('播放加速'),
              subtitle: const Text('自动修复缓慢的播放节点'),
              value: config.enabled,
              onChanged: (value) =>
                  service.updateConfig(config.copyWith(enabled: value)),
            ),
            if (onBoost != null &&
                config.enabled &&
                config.mode != CdnAcceleratorMode.force &&
                (service.status == CdnAcceleratorStatus.buffering ||
                    service.stallCount > 0))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: FilledButton.icon(
                  onPressed: () async {
                    await service.updateConfig(
                      config.copyWith(mode: CdnAcceleratorMode.force),
                    );
                    await onBoost?.call();
                  },
                  icon: const Icon(Icons.bolt),
                  label: const Text('还在卡？加强加速'),
                ),
              ),
            const Divider(height: 28),
            Text('高级设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<CdnSelectionMode>(
              initialValue: config.selection,
              decoration: const InputDecoration(
                labelText: '服务器选择',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: CdnSelectionMode.auto,
                  child: Text('自动选择最快服务器'),
                ),
                DropdownMenuItem(
                  value: CdnSelectionMode.fixed,
                  child: Text('使用固定服务器'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  service.updateConfig(config.copyWith(selection: value));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CdnAcceleratorMode>(
              initialValue: config.mode,
              decoration: const InputDecoration(
                labelText: '加速时机',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: CdnAcceleratorMode.badOnly,
                  child: Text('仅修复慢服务器'),
                ),
                DropdownMenuItem(
                  value: CdnAcceleratorMode.force,
                  child: Text('始终切换服务器'),
                ),
                DropdownMenuItem(
                  value: CdnAcceleratorMode.off,
                  child: Text('关闭 URL 改写'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  service.updateConfig(config.copyWith(mode: value));
                }
              },
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: config.fixedHost),
              optionsBuilder: (value) {
                final query = value.text.toLowerCase();
                return CdnAcceleratorConfig.allHosts.where(
                  (host) => host.toLowerCase().contains(query),
                );
              },
              onSelected: (value) =>
                  service.updateConfig(config.copyWith(fixedHost: value)),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: config.selection == CdnSelectionMode.fixed,
                        decoration: const InputDecoration(
                          labelText: '固定服务器',
                          hintText: '选择或输入 host',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (value) {
                          service.updateConfig(
                            config.copyWith(fixedHost: value),
                          );
                          onFieldSubmitted();
                        },
                      ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<McdnStrategy>(
              initialValue: config.mcdnStrategy,
              decoration: const InputDecoration(
                labelText: 'MCDN 处理',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: McdnStrategy.proxyAll,
                  child: Text('代理所有 MCDN'),
                ),
                DropdownMenuItem(
                  value: McdnStrategy.proxyV1,
                  child: Text('仅代理 /v1/resource'),
                ),
                DropdownMenuItem(
                  value: McdnStrategy.replace,
                  child: Text('直接替换域名'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  service.updateConfig(config.copyWith(mcdnStrategy: value));
                }
              },
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('抓取隐藏 PCDN'),
              subtitle: const Text('将非标准端口服务器视为慢节点（推荐）'),
              value: config.portHeuristic,
              onChanged: (value) =>
                  service.updateConfig(config.copyWith(portHeuristic: value)),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('自动恢复'),
              subtitle: const Text('卡顿时保留进度并切换服务器'),
              value: config.stallRecovery,
              onChanged: (value) =>
                  service.updateConfig(config.copyWith(stallRecovery: value)),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('改写 Akamai'),
              subtitle: const Text('仅当 Akamai 在当前网络很慢时开启'),
              value: config.rewriteAkamai,
              onChanged: (value) =>
                  service.updateConfig(config.copyWith(rewriteAkamai: value)),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: service.status == CdnAcceleratorStatus.probing
                      ? null
                      : () async {
                          final ok = await service.reprobeLast();
                          SmartDialog.showToast(ok ? '测速完成' : '请先打开一个视频后再测速');
                        },
                  icon: const Icon(Icons.speed),
                  label: const Text('重新测速'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Utils.copyText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(service.diagnostics()),
                    );
                    SmartDialog.showToast('诊断报告已复制');
                  },
                  icon: const Icon(Icons.content_copy),
                  label: const Text('复制诊断报告'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CdnAcceleratorService service;

  const _StatusCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, color) = switch (service.status) {
      CdnAcceleratorStatus.off => ('加速已关闭', '打开后自动修复慢节点', Colors.grey),
      CdnAcceleratorStatus.idle => (
        '就绪',
        '打开视频后自动生效',
        Theme.of(context).colorScheme.primary,
      ),
      CdnAcceleratorStatus.probing => (
        '正在寻找最快服务器…',
        '正在为当前网络选择线路',
        Colors.orange,
      ),
      CdnAcceleratorStatus.buffering => (
        '正在切换更快的服务器…',
        '正在从卡顿中恢复',
        Colors.orange,
      ),
      CdnAcceleratorStatus.smooth => (
        '播放流畅',
        service.currentHost ?? '已选择可用线路',
        Colors.green,
      ),
    };
    final useSpeed = service.speedHistory.any((e) => e > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.bolt, color: color, size: 36),
            const SizedBox(height: 6),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: CustomPaint(
                painter: _SpeedPainter(
                  values: List.of(service.speedHistory),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Text(
              useSpeed
                  ? '${service.currentMbps.toStringAsFixed(1)} Mbps · 峰值 ${service.peakMbps.toStringAsFixed(1)} Mbps'
                  : '已缓冲 ${service.bufferAhead.toStringAsFixed(1)} 秒',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '已修复 ${service.rewriteCount} 个连接 · '
              '卡顿 ${service.stallCount} 次 · 恢复 ${service.recoveryCount} 次',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SpeedPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxValue = math.max(1.0, values.reduce(math.max));
    final path = Path();
    for (final (index, value) in values.indexed) {
      final x = size.width * index / math.max(1, values.length - 1);
      final y = size.height - size.height * value / maxValue;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
