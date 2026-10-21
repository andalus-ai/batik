import 'package:batik/batik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> _pumpLoader(
    WidgetTester tester, {
    int lines = 3,
    bool showHeader = true,
    bool showAvatar = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SkeletonLoader(
            lines: lines,
            showHeader: showHeader,
            showAvatar: showAvatar,
            shimmerDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('renders configurable skeleton content', (tester) async {
    await _pumpLoader(tester, lines: 4, showHeader: true, showAvatar: true);

    expect(find.byType(SkeletonLoader), findsOneWidget);
    expect(find.byType(Column), findsWidgets);
    expect(find.byType(Container), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('supports line-only mode', (tester) async {
    await _pumpLoader(tester, lines: 2, showHeader: false, showAvatar: false);

    expect(find.byType(SkeletonLoader), findsOneWidget);
    expect(find.byType(Container), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });
}
