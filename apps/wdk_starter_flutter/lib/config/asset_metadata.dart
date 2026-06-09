import 'package:flutter/material.dart';
import 'package:wdk_flutter/wdk_flutter.dart';
import 'package:wdk_ui/wdk_ui.dart';

/// Display metadata mapping WDK enums to the generic option models the
/// `wdk_ui` selectors consume. Mirrors the RN starter's `assets.ts`/`networks.ts`.

const Map<AssetTicker, ({String name, Color color})> _assetMeta =
    <AssetTicker, ({String name, Color color})>{
      AssetTicker.btc: (name: 'Bitcoin', color: Color(0xFFF7931A)),
      AssetTicker.usdt: (name: 'Tether USD₮', color: Color(0xFF26A17B)),
      AssetTicker.xaut: (name: 'Tether Gold XAU₮', color: Color(0xFFD4AF37)),
    };

const Map<NetworkType, ({String name, Color color})> _networkMeta =
    <NetworkType, ({String name, Color color})>{
      NetworkType.ethereum: (name: 'Ethereum', color: Color(0xFF627EEA)),
      NetworkType.polygon: (name: 'Polygon', color: Color(0xFF8247E5)),
      NetworkType.arbitrum: (name: 'Arbitrum', color: Color(0xFF28A0F0)),
      NetworkType.plasma: (name: 'Plasma', color: Color(0xFF00D395)),
      NetworkType.ton: (name: 'TON', color: Color(0xFF0088CC)),
      NetworkType.tron: (name: 'Tron', color: Color(0xFFFF060A)),
      NetworkType.solana: (name: 'Solana', color: Color(0xFF9945FF)),
      NetworkType.segwit: (name: 'Bitcoin', color: Color(0xFFF7931A)),
      NetworkType.lightning: (name: 'Lightning', color: Color(0xFFF7CA3E)),
    };

String assetSymbol(AssetTicker a) => switch (a) {
  AssetTicker.btc => 'BTC',
  AssetTicker.usdt => 'USD₮',
  AssetTicker.xaut => 'XAU₮',
};

WdkAssetOption assetOption(AssetTicker a) => WdkAssetOption(
  symbol: assetSymbol(a),
  name: _assetMeta[a]?.name ?? a.id,
  color: _assetMeta[a]?.color,
);

WdkNetworkOption networkOption(NetworkType n) => WdkNetworkOption(
  id: n.id,
  name: _networkMeta[n]?.name ?? n.id,
  color: _networkMeta[n]?.color,
);

/// The networks an asset is available on (from the WDK asset→network map).
List<NetworkType> networksForAsset(AssetTicker a) =>
    assetNetworks[a] ?? const <NetworkType>[];

/// Assets the template supports.
const List<AssetTicker> supportedAssets = <AssetTicker>[
  AssetTicker.btc,
  AssetTicker.usdt,
  AssetTicker.xaut,
];
