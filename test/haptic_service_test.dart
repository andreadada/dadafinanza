import 'package:dadafinanza/services/haptic_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('disabled haptics do not call the platform channel', () async {
    await HapticService.light(enabled: false);

    expect(calls, isEmpty);
  });

  test('enabled light haptics use Flutter platform feedback', () async {
    await HapticService.light(enabled: true);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
  });

  test('enabled medium haptics use medium impact', () async {
    await HapticService.medium(enabled: true);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
  });
}
