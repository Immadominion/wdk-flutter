import Flutter
import UIKit

// NATIVE INTEGRATION (milestone M2) — see NATIVE_INTEGRATION.md.
//
// This plugin embeds Holepunch's Bare runtime via `bare-kit` (the same native
// layer react-native-bare-kit wraps). Once the BareKit pod / xcframework is a
// dependency (see flutter_bare_kit.podspec), the worklet methods delegate to:
//
//   import BareKit
//   let worklet = BareWorklet(configuration: BareWorkletConfiguration())
//   worklet.start(name: filename, source: data)        // or a bundle
//   let ipc = BareIPC(worklet: worklet)                 // async read/write of bytes
//
// Inbound IPC bytes are forwarded to Dart over a per-worklet FlutterEventChannel
// ("dev.web3flutter.flutter_bare_kit/ipc/<id>"); `ipcWrite` forwards Dart→worklet.

public class FlutterBareKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterBareKitPlugin()
    // Legacy channel kept for getPlatformVersion / smoke tests.
    let legacy = FlutterMethodChannel(
      name: "flutter_bare_kit", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: legacy)
    // Worklet control channel used by the Dart `Worklet`/`BareIPC` API.
    let methods = FlutterMethodChannel(
      name: "dev.web3flutter.flutter_bare_kit/methods",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    // Worklet lifecycle + IPC. Wired to BareKit in M2 (see header).
    case "startWorklet", "ipcWrite", "ipcEnd", "suspend", "resume", "terminate":
      result(
        FlutterError(
          code: "bare_kit_unwired",
          message:
            "flutter_bare_kit native Bare binding is not wired yet (milestone M2). "
            + "See NATIVE_INTEGRATION.md.",
          details: nil))

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
