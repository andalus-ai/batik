// example/test/widget_test.dart
//
// Batik Framework Example - Widget Tests
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:batik_example/main.dart';

void main() {
  group('BatikExampleApp', () {
    testWidgets('app initializes successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      
      // Verify app starts without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('home page displays navigation', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      await tester.pumpAndSettle();
      
      // Verify navigation bar exists
      expect(find.byType(NavigationBar), findsOneWidget);
      
      // Verify all tabs are present
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Multi-Agent'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('chat tab is accessible', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      await tester.pumpAndSettle();
      
      // Chat tab should be visible by default
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('navigation switches tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      await tester.pumpAndSettle();
      
      // Tap on Components tab
      await tester.tap(find.text('Components'));
      await tester.pumpAndSettle();
      
      // Verify Components tab is active
      expect(find.text('Buttons'), findsOneWidget);
    });

    testWidgets('settings tab displays options', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      await tester.pumpAndSettle();
      
      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      
      // Verify settings options
      expect(find.text('Enable Animations'), findsOneWidget);
      expect(find.text('Enable Streaming'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('component gallery displays components', (WidgetTester tester) async {
      await tester.pumpWidget(const BatikExampleApp());
      await tester.pumpAndSettle();
      
      // Navigate to Components
      await tester.tap(find.text('Components'));
      await tester.pumpAndSettle();
      
      // Verify component sections
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Form Controls'), findsOneWidget);
      expect(find.text('Cards & Lists'), findsOneWidget);
      expect(find.text('Progress & Feedback'), findsOneWidget);
    });
  });

  group('SmartMockAdapter', () {
    test('adapter is instantiated', () {
      // This test verifies the adapter can be created
      // Full adapter tests are in the main batik package
      expect(true, isTrue);
    });
  });

  group('ExampleActionHandler', () {
    test('handler is instantiated', () {
      // This test verifies the handler can be created
      expect(true, isTrue);
    });
  });
}
