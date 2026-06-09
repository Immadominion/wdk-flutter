import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wdk_flutter/wdk_flutter.dart';

/// The asset chosen during an in-progress send/receive flow.
final StateProvider<AssetTicker?> selectedAssetProvider =
    StateProvider<AssetTicker?>((Ref ref) => null);

/// The network chosen during an in-progress send/receive flow.
final StateProvider<NetworkType?> selectedNetworkProvider =
    StateProvider<NetworkType?>((Ref ref) => null);
