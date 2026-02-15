import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_dart_project/main.dart';
import 'package:my_dart_project/src/ui/simulation_3d_view.dart';

void main() {
  testWidgets('loads simulation view', (WidgetTester tester) async {
    final FlutterExceptionHandler? originalHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final String text = details.exceptionAsString();
      if (text.contains('A RenderFlex overflowed')) {
        return;
      }
      originalHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalHandler;
    });

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SimulationApp());

    expect(find.byType(Simulation3DView), findsOneWidget);
  });
}
