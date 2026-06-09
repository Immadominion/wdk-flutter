import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_bare_kit_method_channel.dart';

abstract class FlutterBareKitPlatform extends PlatformInterface {
  /// Constructs a FlutterBareKitPlatform.
  FlutterBareKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBareKitPlatform _instance = MethodChannelFlutterBareKit();

  /// The default instance of [FlutterBareKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBareKit].
  static FlutterBareKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBareKitPlatform] when
  /// they register themselves.
  static set instance(FlutterBareKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
