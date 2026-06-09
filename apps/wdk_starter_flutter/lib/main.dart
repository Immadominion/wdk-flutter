import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wdk_flutter/wdk_flutter.dart';
import 'package:wdk_ui/wdk_ui.dart';

import 'app_state.dart';
import 'config/asset_metadata.dart';
import 'config/chains.dart';

/// Brand color (mirrors the RN starter's `colors.primary`).
const Color kBrandColor = Color(0xFF1BA27A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: <Override>[
        wdkConfigProvider.overrideWithValue(_buildConfig()),
      ],
      child: const WdkStarterApp(),
    ),
  );
}

WdkConfig _buildConfig() {
  return WdkConfig(
    indexer: const IndexerConfig(
      apiKey: String.fromEnvironment('WDK_INDEXER_API_KEY'),
      url: String.fromEnvironment(
        'WDK_INDEXER_URL',
        defaultValue: 'https://wdk-api.tether.io',
      ),
    ),
    chains: getChainsConfig(),
    enableCaching: true,
  );
}

/// Boots the WDK engine once (mirrors the RN `_layout.tsx` initialize call).
final FutureProvider<void> bootstrapProvider =
    FutureProvider<void>((Ref ref) async {
  final WdkConfig config = ref.read(wdkConfigProvider);
  await ref.read(wdkServiceProvider).initialize(config);
  ref.read(walletProvider.notifier).markInitialized();
});

class WdkStarterApp extends StatelessWidget {
  const WdkStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WDK Wallet',
      debugShowCheckedModeBanner: false,
      theme: buildWdkThemeData(
        primaryColor: kBrandColor,
        brightness: Brightness.light,
      ),
      darkTheme: buildWdkThemeData(
        primaryColor: kBrandColor,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

// Routes mirror the React Native expo-router screen tree.
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => const GateScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/authorize', builder: (_, _) => const AuthorizeScreen()),
    GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
    GoRoute(path: '/assets', builder: (_, _) => const AssetsScreen()),
    GoRoute(path: '/activity', builder: (_, _) => const ActivityScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/wallet-setup/secure',
      builder: (_, _) => const SecureWalletScreen(),
    ),
    GoRoute(
      path: '/wallet-setup/import',
      builder: (_, _) => const _PlaceholderScreen('Import wallet'),
    ),
    GoRoute(
      path: '/scan-qr',
      builder: (_, _) => const _PlaceholderScreen('Scan QR (camera)'),
    ),
    GoRoute(
      path: '/send/select-token',
      builder: (_, _) => const SelectTokenScreen(flow: TxFlow.send),
    ),
    GoRoute(
      path: '/send/select-network',
      builder: (_, _) => const SelectNetworkScreen(flow: TxFlow.send),
    ),
    GoRoute(path: '/send/details', builder: (_, _) => const SendDetailsScreen()),
    GoRoute(
      path: '/receive/select-token',
      builder: (_, _) => const SelectTokenScreen(flow: TxFlow.receive),
    ),
    GoRoute(
      path: '/receive/select-network',
      builder: (_, _) => const SelectNetworkScreen(flow: TxFlow.receive),
    ),
    GoRoute(
      path: '/receive/details',
      builder: (_, _) => const ReceiveDetailsScreen(),
    ),
  ],
);

enum TxFlow { send, receive }

// --- Gate / onboarding / authorize ----------------------------------------

class GateScreen extends ConsumerWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> boot = ref.watch(bootstrapProvider);
    return boot.when(
      loading: () => const _LoadingScaffold(),
      error: (Object e, _) =>
          Scaffold(body: Center(child: Text('Failed to initialize WDK:\n$e'))),
      data: (_) {
        final WalletInfo? wallet = ref.watch(walletInfoProvider);
        final bool unlocked = ref.watch(isUnlockedProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (wallet == null) {
            context.go('/onboarding');
          } else if (!unlocked) {
            context.go('/authorize');
          } else {
            context.go('/wallet');
          }
        });
        return const _LoadingScaffold();
      },
    );
  }
}

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WdkTheme t = context.wdk;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.account_balance_wallet, size: 64, color: t.primary),
              const SizedBox(height: 16),
              Text('WDK Wallet',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'A self-custodial multi-chain wallet powered by Tether WDK.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/wallet-setup/secure'),
                child: const Text('Create a new wallet'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/wallet-setup/import'),
                child: const Text('Import an existing wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthorizeScreen extends ConsumerWidget {
  const AuthorizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.fingerprint),
          label: const Text('Unlock'),
          onPressed: () async {
            final bool ok =
                await ref.read(walletProvider.notifier).unlockWallet();
            if (ok && context.mounted) context.go('/wallet');
          },
        ),
      ),
    );
  }
}

// --- Wallet setup (seed) ----------------------------------------------------

class SecureWalletScreen extends ConsumerWidget {
  const SecureWalletScreen({super.key});

  // A fixed sample phrase for the UI demo. The real seed is generated and
  // encrypted inside the WDK secret-manager worklet (milestone M2).
  static const List<String> _sample = <String>[
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WdkTheme t = context.wdk;
    return Scaffold(
      appBar: AppBar(title: const Text('Your recovery phrase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Banner(
              'Sample phrase. Your real seed is generated and encrypted inside '
              'the WDK worklet once the native binding lands (M2).',
            ),
            const SizedBox(height: 16),
            const WdkSeedPhrase(words: _sample),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(walletProvider.notifier)
                    .createWallet(name: 'My Wallet');
                if (context.mounted) context.go('/wallet');
              },
              child: const Text("I've saved it — continue"),
            ),
            const SizedBox(height: 8),
            Text(
              'Never share your recovery phrase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Wallet dashboard -------------------------------------------------------

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransactionRecord> txs = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.go('/assets'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Center(child: WdkBalance(value: '0.00', currency: 'USD')),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Send'),
                  onPressed: () => context.go('/send/select-token'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Receive'),
                  onPressed: () => context.go('/receive/select-token'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Recent activity',
                style: TextStyle(color: context.wdk.textSecondary)),
          ),
          WdkTransactionList(items: txs.map(_toTxItem).toList()),
        ],
      ),
    );
  }
}

WdkTxItem _toTxItem(TransactionRecord t) => WdkTxItem(
      sent: false,
      token: assetSymbol(t.asset),
      amount: t.amount,
      network: networkOption(t.network).name,
      timestamp: t.timestamp,
    );

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: const Text('Assets'),
      ),
      body: WdkAssetSelector(
        options: supportedAssets.map(assetOption).toList(),
        onSelected: (_) {},
      ),
    );
  }
}

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransactionRecord> txs = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: const Text('Activity'),
      ),
      body: WdkTransactionList(items: txs.map(_toTxItem).toList()),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete wallet'),
            onTap: () async {
              await ref.read(walletProvider.notifier).clearWallet();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }
}

// --- Send / receive selection ----------------------------------------------

class SelectTokenScreen extends ConsumerWidget {
  const SelectTokenScreen({required this.flow, super.key});
  final TxFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String base = flow == TxFlow.send ? '/send' : '/receive';
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: Text(flow == TxFlow.send ? 'Send · token' : 'Receive · token'),
      ),
      body: WdkAssetSelector(
        options: supportedAssets.map(assetOption).toList(),
        onSelected: (WdkAssetOption o) {
          ref.read(selectedAssetProvider.notifier).state =
              AssetTicker.values.firstWhere((AssetTicker a) => assetSymbol(a) == o.symbol);
          context.go('$base/select-network');
        },
      ),
    );
  }
}

class SelectNetworkScreen extends ConsumerWidget {
  const SelectNetworkScreen({required this.flow, super.key});
  final TxFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AssetTicker? asset = ref.watch(selectedAssetProvider);
    final String base = flow == TxFlow.send ? '/send' : '/receive';
    if (asset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('$base/select-token');
      });
      return const _LoadingScaffold();
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('$base/select-token')),
        title: const Text('Network'),
      ),
      body: WdkNetworkSelector(
        options: networksForAsset(asset).map(networkOption).toList(),
        onSelected: (WdkNetworkOption o) {
          ref.read(selectedNetworkProvider.notifier).state =
              NetworkType.fromId(o.id);
          context.go('$base/details');
        },
      ),
    );
  }
}

// --- Send details -----------------------------------------------------------

class SendDetailsScreen extends ConsumerStatefulWidget {
  const SendDetailsScreen({super.key});
  @override
  ConsumerState<SendDetailsScreen> createState() => _SendDetailsScreenState();
}

class _SendDetailsScreenState extends ConsumerState<SendDetailsScreen> {
  String _address = '';
  String _amount = '';

  @override
  Widget build(BuildContext context) {
    final AssetTicker? asset = ref.watch(selectedAssetProvider);
    final NetworkType? network = ref.watch(selectedNetworkProvider);
    if (asset == null || network == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/send/select-token');
      });
      return const _LoadingScaffold();
    }
    final bool addressValid = AddressValidator.isValid(network, _address);
    final bool canSend = addressValid && (double.tryParse(_amount) ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/send/select-network')),
        title: Text('Send ${assetSymbol(asset)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          WdkAmountInput(
            value: _amount,
            symbol: assetSymbol(asset),
            onChanged: (String v) => setState(() => _amount = v),
          ),
          const SizedBox(height: 16),
          WdkAddressInput(
            value: _address,
            onChanged: (String v) => setState(() => _address = v),
            validator: (String v) =>
                AddressValidator.validationError(network, v),
            onScan: () => context.go('/scan-qr'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSend ? () => _send(asset, network) : null,
            child: const Text('Review & send'),
          ),
        ],
      ),
    );
  }

  Future<void> _send(AssetTicker asset, NetworkType network) async {
    try {
      final SendResult r = await ref.read(wdkServiceProvider).sendByNetwork(
            network: network,
            accountIndex: 0,
            amount: double.parse(_amount),
            recipient: _address,
            asset: asset,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent: ${r.hash}')),
        );
      }
    } on WorkletUnavailable {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Validated ✓ — broadcasting needs the WDK worklet binding (M2).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// --- Receive details --------------------------------------------------------

class ReceiveDetailsScreen extends ConsumerWidget {
  const ReceiveDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AssetTicker? asset = ref.watch(selectedAssetProvider);
    final NetworkType? network = ref.watch(selectedNetworkProvider);
    if (asset == null || network == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/receive/select-token');
      });
      return const _LoadingScaffold();
    }
    final Map<NetworkType, String> addresses = ref.watch(addressesProvider);
    final String address = addresses[network] ?? _sampleAddress(network);

    return Scaffold(
      appBar: AppBar(
        leading:
            BackButton(onPressed: () => context.go('/receive/select-network')),
        title: Text('Receive ${assetSymbol(asset)}'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              if (!addresses.containsKey(network))
                _Banner('Sample address — real addresses come from the worklet (M2).'),
              const SizedBox(height: 16),
              WdkQrCode(data: address, label: address),
            ],
          ),
        ),
      ),
    );
  }
}

String _sampleAddress(NetworkType n) => switch (n) {
      NetworkType.segwit => 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
      NetworkType.ton => 'EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N',
      NetworkType.tron => 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE',
      NetworkType.solana => 'So11111111111111111111111111111111111111112',
      _ => '0x52908400098527886E0F7030069857D2E4169EE7',
    };

// --- Shared -----------------------------------------------------------------

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: t.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '“$title” is part of the screen map mirrored from the React '
            'Native starter. It is completed in milestones M2–M3.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}
