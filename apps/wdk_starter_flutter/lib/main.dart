import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wdk_flutter/wdk_flutter.dart';
import 'package:wdk_ui/wdk_ui.dart';

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

/// Boots the WDK engine once. Mirrors the RN `_layout.tsx` calling
/// `WDKService.initialize()` then rendering the gate.
final FutureProvider<void> bootstrapProvider = FutureProvider<void>((Ref ref) async {
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

// ---------------------------------------------------------------------------
// Routes — mirror the React Native expo-router screen tree. Screens marked
// `_PlaceholderScreen` are wired to the provider in milestones M2/M3.
// ---------------------------------------------------------------------------

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => const GateScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/authorize', builder: (_, _) => const AuthorizeScreen()),
    GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
    GoRoute(
      path: '/assets',
      builder: (_, _) => const _PlaceholderScreen('Assets'),
    ),
    GoRoute(
      path: '/activity',
      builder: (_, _) => const _PlaceholderScreen('Activity'),
    ),
    GoRoute(
      path: '/token-details',
      builder: (_, _) => const _PlaceholderScreen('Token details'),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/scan-qr',
      builder: (_, _) => const _PlaceholderScreen('Scan QR'),
    ),
    // Wallet setup
    GoRoute(
      path: '/wallet-setup/name',
      builder: (_, _) => const _PlaceholderScreen('Name wallet'),
    ),
    GoRoute(
      path: '/wallet-setup/secure',
      builder: (_, _) => const _PlaceholderScreen('Secure wallet (seed)'),
    ),
    GoRoute(
      path: '/wallet-setup/confirm',
      builder: (_, _) => const _PlaceholderScreen('Confirm phrase'),
    ),
    GoRoute(
      path: '/wallet-setup/complete',
      builder: (_, _) => const _PlaceholderScreen('Setup complete'),
    ),
    GoRoute(
      path: '/wallet-setup/import',
      builder: (_, _) => const _PlaceholderScreen('Import wallet'),
    ),
    GoRoute(
      path: '/wallet-setup/import-name',
      builder: (_, _) => const _PlaceholderScreen('Name imported wallet'),
    ),
    // Send
    GoRoute(
      path: '/send/select-token',
      builder: (_, _) => const _PlaceholderScreen('Send · select token'),
    ),
    GoRoute(
      path: '/send/select-network',
      builder: (_, _) => const _PlaceholderScreen('Send · select network'),
    ),
    GoRoute(
      path: '/send/details',
      builder: (_, _) => const _PlaceholderScreen('Send · details'),
    ),
    // Receive
    GoRoute(
      path: '/receive/select-token',
      builder: (_, _) => const _PlaceholderScreen('Receive · select token'),
    ),
    GoRoute(
      path: '/receive/select-network',
      builder: (_, _) => const _PlaceholderScreen('Receive · select network'),
    ),
    GoRoute(
      path: '/receive/details',
      builder: (_, _) => const _PlaceholderScreen('Receive · details'),
    ),
  ],
);

/// App entry gate — mirrors the RN `index.tsx` redirect logic.
class GateScreen extends ConsumerWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> boot = ref.watch(bootstrapProvider);
    return boot.when(
      loading: () => const _LoadingScaffold(),
      error: (Object e, _) => Scaffold(
        body: Center(child: Text('Failed to initialize WDK:\n$e')),
      ),
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
              Text(
                'WDK Wallet',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A self-custodial multi-chain wallet powered by Tether WDK.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () async {
                  // M2: real flow is name → secure (seed) → confirm → complete.
                  await ref
                      .read(walletProvider.notifier)
                      .createWallet(name: 'My Wallet');
                  if (context.mounted) context.go('/wallet');
                },
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

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WdkTheme t = context.wdk;
    final List<WalletBalance> balances = ref.watch(balancesProvider);
    final List<TransactionRecord> txs = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const WdkBalance(value: '0.00', currency: 'USD'),
            const SizedBox(height: 8),
            Text(
              '${balances.length} balances · ${txs.length} transactions',
              style: TextStyle(color: t.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.go('/send/select-token'),
                    child: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.go('/receive/select-token'),
                    child: const Text('Receive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Live balances, history, and send/receive are wired to the WDK '
              'worklet in milestones M2–M3 (see ROADMAP.md).',
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
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
            'Native starter. It is implemented in milestones M2–M3.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}
