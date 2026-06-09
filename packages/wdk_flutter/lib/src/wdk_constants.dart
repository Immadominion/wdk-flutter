import 'wdk_core.dart';

/// Token denomination (smallest-unit multiplier) per asset.
/// Mirrors `WDKService.getDenominationValue`: BTC = 1e8, USD₮/XAU₮ = 1e6.
BigInt denominationFor(AssetTicker asset) {
  switch (asset) {
    case AssetTicker.btc:
      return BigInt.from(100000000);
    case AssetTicker.usdt:
    case AssetTicker.xaut:
      return BigInt.from(1000000);
  }
}

/// Number of decimals per asset (BTC 8, USD₮/XAU₮ 6).
int decimalsFor(AssetTicker asset) => asset == AssetTicker.btc ? 8 : 6;

/// ERC-20 / jetton contract addresses WDK uses for balances + transfers,
/// copied verbatim from `SMART_CONTRACT_BALANCE_ADDRESSES` in the RN provider.
const Map<AssetTicker, Map<NetworkType, String>> smartContractAddresses =
    <AssetTicker, Map<NetworkType, String>>{
      AssetTicker.usdt: <NetworkType, String>{
        NetworkType.ethereum: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        NetworkType.polygon: '0xc2132d05d31c914a87c6611c10748aeb04b58e8f',
        NetworkType.arbitrum: '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
        NetworkType.ton: 'EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs',
      },
      AssetTicker.xaut: <NetworkType, String>{
        NetworkType.ethereum: '0x68749665FF8D2d112Fa859AA293F07A622782F38',
        NetworkType.polygon: '0xF1815bd50389c46847f0Bda824eC8da914045D14',
        NetworkType.arbitrum: '0x40461291347e1eCbb09499F3371D3f17f10d7159',
        NetworkType.ton: 'EQA1R_LuQCLHlMgOo1S4G7Y7W1cd0FrAkbA10Zq7rddKxi9k',
      },
    };

/// Networks each asset's balance/transfers are queried on (`AssetBalanceMap`).
const Map<AssetTicker, List<NetworkType>> assetNetworks =
    <AssetTicker, List<NetworkType>>{
      AssetTicker.btc: <NetworkType>[NetworkType.segwit],
      AssetTicker.usdt: <NetworkType>[
        NetworkType.ethereum,
        NetworkType.polygon,
        NetworkType.arbitrum,
        NetworkType.ton,
      ],
      AssetTicker.xaut: <NetworkType>[NetworkType.ethereum],
    };

/// Networks that use ERC-4337 account abstraction (abstracted address + send).
/// Bitcoin (SegWit) uses a direct address/transaction path instead.
const Set<NetworkType> abstractedNetworks = <NetworkType>{
  NetworkType.ethereum,
  NetworkType.polygon,
  NetworkType.arbitrum,
  NetworkType.ton,
};
