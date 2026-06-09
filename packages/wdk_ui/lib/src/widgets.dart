import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'wdk_theme.dart';

/// Portfolio/asset balance with an optional fiat line — analog of RN `Balance`.
class WdkBalance extends StatelessWidget {
  const WdkBalance({
    required this.value,
    this.currency = '',
    this.isLoading = false,
    super.key,
  });

  final String value;
  final String currency;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    if (isLoading) {
      return const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (currency.isNotEmpty) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            currency,
            style: TextStyle(color: t.textSecondary, fontSize: 18),
          ),
        ],
      ],
    );
  }
}

/// A recipient-address input with paste/scan affordances and inline validation.
/// Validation is injected via [validator] so the kit stays business-logic-free.
class WdkAddressInput extends StatelessWidget {
  const WdkAddressInput({
    required this.value,
    required this.onChanged,
    this.validator,
    this.onScan,
    this.hintText = 'Recipient address',
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? Function(String value)? validator;
  final VoidCallback? onScan;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    final String? error = value.isEmpty ? null : validator?.call(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          onChanged: onChanged,
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: t.card,
            errorText: error,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.border),
              borderRadius: BorderRadius.circular(12),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: onScan == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    color: t.primary,
                    onPressed: onScan,
                  ),
          ),
        ),
      ],
    );
  }
}

/// An amount field with a token symbol, balance line, and a "max" button.
class WdkAmountInput extends StatelessWidget {
  const WdkAmountInput({
    required this.value,
    required this.onChanged,
    required this.symbol,
    this.balanceLabel,
    this.fiatLabel,
    this.onMax,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String symbol;
  final String? balanceLabel;
  final String? fiatLabel;
  final VoidCallback? onMax;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Text(
                symbol,
                style: TextStyle(color: t.textSecondary, fontSize: 18),
              ),
              if (onMax != null) ...<Widget>[
                const SizedBox(width: 8),
                TextButton(onPressed: onMax, child: const Text('MAX')),
              ],
            ],
          ),
          if (fiatLabel != null)
            Text(fiatLabel!, style: TextStyle(color: t.textSecondary)),
          if (balanceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Balance: $balanceLabel',
                style: TextStyle(color: t.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// A selectable asset (e.g. BTC / USD₮ / XAU₮).
@immutable
class WdkAssetOption {
  const WdkAssetOption({required this.symbol, required this.name, this.color});
  final String symbol;
  final String name;
  final Color? color;
}

/// A vertical asset picker — analog of RN `AssetSelector`.
class WdkAssetSelector extends StatelessWidget {
  const WdkAssetSelector({
    required this.options,
    required this.onSelected,
    super.key,
  });

  final List<WdkAssetOption> options;
  final ValueChanged<WdkAssetOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return ListView.separated(
      shrinkWrap: true,
      itemCount: options.length,
      separatorBuilder: (_, _) => Divider(color: t.border, height: 1),
      itemBuilder: (BuildContext context, int i) {
        final WdkAssetOption o = options[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: o.color ?? t.primary,
            child: Text(
              o.symbol.isNotEmpty ? o.symbol.characters.first : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(o.symbol, style: TextStyle(color: t.textPrimary)),
          subtitle: Text(o.name, style: TextStyle(color: t.textSecondary)),
          onTap: () => onSelected(o),
        );
      },
    );
  }
}

/// A selectable network.
@immutable
class WdkNetworkOption {
  const WdkNetworkOption({required this.id, required this.name, this.color});
  final String id;
  final String name;
  final Color? color;
}

/// A network picker — analog of RN `NetworkSelector`.
class WdkNetworkSelector extends StatelessWidget {
  const WdkNetworkSelector({
    required this.options,
    required this.onSelected,
    super.key,
  });

  final List<WdkNetworkOption> options;
  final ValueChanged<WdkNetworkOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return ListView.separated(
      shrinkWrap: true,
      itemCount: options.length,
      separatorBuilder: (_, _) => Divider(color: t.border, height: 1),
      itemBuilder: (BuildContext context, int i) {
        final WdkNetworkOption o = options[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: o.color ?? t.primary,
            radius: 10,
          ),
          title: Text(o.name, style: TextStyle(color: t.textPrimary)),
          onTap: () => onSelected(o),
        );
      },
    );
  }
}

/// One transaction row.
@immutable
class WdkTxItem {
  const WdkTxItem({
    required this.sent,
    required this.token,
    required this.amount,
    required this.network,
    this.fiat,
    this.timestamp,
  });
  final bool sent;
  final String token;
  final String amount;
  final String network;
  final String? fiat;
  final DateTime? timestamp;
}

/// A transaction history list — analog of RN `TransactionList`.
class WdkTransactionList extends StatelessWidget {
  const WdkTransactionList({
    required this.items,
    this.emptyLabel = 'No transactions yet',
    super.key,
  });

  final List<WdkTxItem> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(emptyLabel, style: TextStyle(color: t.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(color: t.border, height: 1),
      itemBuilder: (BuildContext context, int i) {
        final WdkTxItem tx = items[i];
        return ListTile(
          leading: Icon(
            tx.sent ? Icons.arrow_upward : Icons.arrow_downward,
            color: tx.sent ? t.danger : t.success,
          ),
          title: Text(
            '${tx.sent ? 'Sent' : 'Received'} ${tx.token}',
            style: TextStyle(color: t.textPrimary),
          ),
          subtitle: Text(tx.network, style: TextStyle(color: t.textSecondary)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${tx.sent ? '-' : '+'}${tx.amount}',
                style: TextStyle(color: tx.sent ? t.textPrimary : t.success),
              ),
              if (tx.fiat != null)
                Text(
                  tx.fiat!,
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A QR code for a receive address — analog of RN `QRCode`.
class WdkQrCode extends StatelessWidget {
  const WdkQrCode({required this.data, this.size = 220, this.label, super.key});

  final String data;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(data: data, version: QrVersions.auto, size: size),
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// A 12/24-word seed phrase grid with a reveal toggle — analog of RN
/// `SeedPhrase`. Pass [obscured] to start hidden.
class WdkSeedPhrase extends StatefulWidget {
  const WdkSeedPhrase({required this.words, this.obscured = true, super.key});

  final List<String> words;
  final bool obscured;

  @override
  State<WdkSeedPhrase> createState() => _WdkSeedPhraseState();
}

class _WdkSeedPhraseState extends State<WdkSeedPhrase> {
  late bool _hidden = widget.obscured;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (int i = 0; i < widget.words.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  '${i + 1}. ${_hidden ? '••••' : widget.words[i]}',
                  style: TextStyle(color: t.textPrimary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
          label: Text(_hidden ? 'Reveal' : 'Hide'),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ],
    );
  }
}
