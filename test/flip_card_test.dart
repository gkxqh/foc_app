import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/views/common/flip_card.dart';

Widget _host({
  required bool disableAnimations,
  required ValueChanged<bool> onFlip,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: FlipCard(
              front: const Text('正面'),
              back: const Text('背面'),
              onFlip: onFlip,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('点击正面翻到背面，再点翻回正面（onFlip 随半程切换）', (tester) async {
    final faces = <bool>[];
    await tester.pumpWidget(_host(disableAnimations: false, onFlip: faces.add));

    expect(find.text('正面'), findsOneWidget);
    expect(find.text('背面'), findsNothing);
    expect(faces, isEmpty);

    await tester.tap(find.byType(FlipCard));
    // 第一帧启动 Ticker（elapsed=0），再推进 500ms 动画的过半处
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('背面'), findsOneWidget);
    expect(find.text('正面'), findsNothing);
    expect(faces, [true]);

    await tester.pumpAndSettle();
    await tester.tap(find.byType(FlipCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('正面'), findsOneWidget);
    expect(find.text('背面'), findsNothing);
    expect(faces, [true, false]);

    await tester.pumpAndSettle();
  });

  testWidgets('系统开启减弱动态时，点击一帧内直接切换无动画', (tester) async {
    final faces = <bool>[];
    await tester.pumpWidget(_host(disableAnimations: true, onFlip: faces.add));
    await tester.pump();

    await tester.tap(find.byType(FlipCard));
    await tester.pump();
    expect(find.text('背面'), findsOneWidget);
    expect(faces, [true]);

    await tester.tap(find.byType(FlipCard));
    await tester.pump();
    expect(find.text('正面'), findsOneWidget);
    expect(faces, [true, false]);
  });
}
