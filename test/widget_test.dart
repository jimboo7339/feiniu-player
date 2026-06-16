import 'package:feiniu_player/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots to login or splash', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FeiniuPlayerApp()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
