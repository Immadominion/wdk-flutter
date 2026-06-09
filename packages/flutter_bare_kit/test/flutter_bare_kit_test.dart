import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bare_kit/flutter_bare_kit.dart';
import 'package:flutter_bare_kit/flutter_bare_kit_platform_interface.dart';
import 'package:flutter_bare_kit/flutter_bare_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBareKitPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBareKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterBareKitPlatform initialPlatform =
      FlutterBareKitPlatform.instance;

  test('$MethodChannelFlutterBareKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBareKit>());
  });

  test('getPlatformVersion', () async {
    FlutterBareKit flutterBareKitPlugin = FlutterBareKit();
    MockFlutterBareKitPlatform fakePlatform = MockFlutterBareKitPlatform();
    FlutterBareKitPlatform.instance = fakePlatform;

    expect(await flutterBareKitPlugin.getPlatformVersion(), '42');
  });
}
