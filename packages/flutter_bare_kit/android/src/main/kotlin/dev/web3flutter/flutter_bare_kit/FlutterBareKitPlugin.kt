package dev.web3flutter.flutter_bare_kit

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// NATIVE INTEGRATION (milestone M2) — see NATIVE_INTEGRATION.md.
//
// This plugin embeds Holepunch's Bare runtime via `bare-kit` (the same native
// layer react-native-bare-kit wraps). Once `bare-kit` is on the classpath, the
// worklet methods below delegate to its Java API:
//
//   import to.holepunch.bare.kit.Worklet
//   import to.holepunch.bare.kit.IPC
//
//   val worklet = Worklet(Worklet.Options())
//   worklet.start(filename, source /* or bundle */, args)
//   val ipc = IPC(worklet)   // non-blocking read/write of raw bytes
//
// Inbound IPC bytes are forwarded to Dart over a per-worklet EventChannel
// ("dev.web3flutter.flutter_bare_kit/ipc/<id>"); `ipcWrite` forwards Dart→worklet.

/** FlutterBareKitPlugin */
class FlutterBareKitPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var legacyChannel: MethodChannel
    private lateinit var methodsChannel: MethodChannel
    private var messenger: BinaryMessenger? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
        // Legacy channel kept for getPlatformVersion / smoke tests.
        legacyChannel = MethodChannel(binding.binaryMessenger, "flutter_bare_kit")
        legacyChannel.setMethodCallHandler(this)
        // Worklet control channel used by the Dart `Worklet`/`BareIPC` API.
        methodsChannel =
            MethodChannel(binding.binaryMessenger, "dev.web3flutter.flutter_bare_kit/methods")
        methodsChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "getPlatformVersion" ->
                result.success("Android ${android.os.Build.VERSION.RELEASE}")

            // Worklet lifecycle + IPC. Wired to bare-kit in M2 (see header).
            "startWorklet",
            "ipcWrite",
            "ipcEnd",
            "suspend",
            "resume",
            "terminate",
            ->
                result.error(
                    "bare_kit_unwired",
                    "flutter_bare_kit native Bare binding is not wired yet " +
                        "(milestone M2). See NATIVE_INTEGRATION.md.",
                    null,
                )

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        legacyChannel.setMethodCallHandler(null)
        methodsChannel.setMethodCallHandler(null)
        messenger = null
    }
}
