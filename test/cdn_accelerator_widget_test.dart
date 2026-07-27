import 'package:PiliPlus/pages/setting/pages/cdn_accelerator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accelerator page exposes status and advanced controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CdnAcceleratorPage()));

    expect(find.text('播放加速'), findsWidgets);
    expect(find.text('高级设置'), findsOneWidget);
    expect(find.text('服务器选择'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('MCDN 处理'), findsOneWidget);
    expect(find.text('抓取隐藏 PCDN'), findsOneWidget);
    expect(find.text('自动恢复'), findsOneWidget);
    expect(find.text('复制诊断报告'), findsOneWidget);
  });
}
