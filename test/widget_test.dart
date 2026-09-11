import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/main.dart';
import 'package:foc_app/providers/config_provider.dart';
import 'package:foc_app/views/home/repair_terms_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('FeiyangApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FeiyangApp());
    // Drain microtasks and frame callbacks
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FeiyangApp), findsOneWidget);
  });

  testWidgets('RepairTermsPage scroll and checkbox interaction test', (
    WidgetTester tester,
  ) async {
    // Set small viewport to ensure content requires scrolling
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final configProvider = ConfigProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigProvider>.value(
        value: configProvider,
        child: const MaterialApp(
          home: RepairTermsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报修须知与服务条款'), findsOneWidget);

    // Initial state: checkbox is unselected
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    Checkbox checkbox = tester.widget(checkboxFinder);
    expect(checkbox.value, false);

    // Tap checkbox without scrolling to bottom
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    // Verification: SnackBar with prompt is displayed
    expect(find.text('看都没看完点什么点(#`Д´)ﾉ'), findsOneWidget);
    checkbox = tester.widget(checkboxFinder);
    expect(checkbox.value, false);

    // Now scroll all the way to the bottom
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    // Tap checkbox again after scrolling to bottom
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    // Checkbox should now be checked
    checkbox = tester.widget(checkboxFinder);
    expect(checkbox.value, true);

    // Submit button should be enabled
    final submitButtonFinder = find.widgetWithText(ElevatedButton, '我已知晓并同意，开始报修');
    expect(submitButtonFinder, findsOneWidget);
    final ElevatedButton submitButton = tester.widget(submitButtonFinder);
    expect(submitButton.onPressed, isNotNull);
  });
}

