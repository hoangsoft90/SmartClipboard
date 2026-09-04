import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_limits.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/expansion_engine.dart';
import '../../services/metrics_service.dart';
import '../../state/providers.dart';

class PlaygroundScreen extends ConsumerStatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  ConsumerState<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends ConsumerState<PlaygroundScreen> {
  final _controller = TextEditingController();
  String? _lastExpandedContent;
  String? _lastExpandedTrigger;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final engine = ref.read(expansionEngineProvider);
    final outcome = engine.processInput(text);
    if (!outcome.changed) return;

    _controller.value = TextEditingValue(
      text: outcome.outputText,
      selection: TextSelection.collapsed(offset: outcome.outputText.length),
    );

    if (outcome.expandedTrigger != null && outcome.expandedSnippetId != null) {
      setState(() {
        _lastExpandedTrigger = outcome.expandedTrigger;
        _lastExpandedContent = engine.triggerToContent[outcome.expandedTrigger];
      });
      _trackUsage(outcome);
    }
  }

  Future<void> _trackUsage(ExpansionOutcome outcome) async {
    await ref.read(metricsProvider).increment(MetricsService.kExpansionCount);
    await ref
        .read(metricsProvider)
        .increment(MetricsService.kPlaygroundExpansions);
    await ref.read(metricsProvider).markActiveToday();
    if (outcome.expandedSnippetId != null) {
      await ref
          .read(snippetRepoProvider)
          .incrementUsage(outcome.expandedSnippetId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snippetCount =
        ref.watch(snippetListProvider).value?.where((s) => s.isEnabled).length ??
            0;
    final activationState = ref.watch(keyboardActivationStateProvider).value ?? KeyboardActivationState.disabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playgroundTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 8,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: l10n.playgroundHintText(
                  snippetCount > 0 ? ";trigger" : ";email"),
              border: const OutlineInputBorder(),
              helperText: l10n.playgroundHelperText,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          if (_lastExpandedContent != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment:
                    CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.auto_fix_high,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          l10n.playgroundExpanded(_lastExpandedTrigger!),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme.onSecondaryContainer)),
                    ),
                    IconButton(
                      tooltip: l10n.playgroundCopyResult,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text: _lastExpandedContent ?? ''));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.playgroundCopied)));
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(_lastExpandedContent!),
                ]),
              ),
            ),

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                switch (activationState) {
                  KeyboardActivationState.disabled => Icons.keyboard_alt_outlined,
                  KeyboardActivationState.enabledNotActive => Icons.swap_horiz,
                  KeyboardActivationState.active => Icons.check_circle,
                },
              ),
              title: Text(
                switch (activationState) {
                  KeyboardActivationState.disabled => l10n.playgroundKeyboardDisabled,
                  KeyboardActivationState.enabledNotActive => l10n.playgroundKeyboardEnabled,
                  KeyboardActivationState.active => l10n.playgroundKeyboardEnabled,
                },
              ),
              subtitle: Text(
                switch (activationState) {
                  KeyboardActivationState.disabled => l10n.playgroundKeyboardSubtitle,
                  KeyboardActivationState.enabledNotActive => l10n.playgroundTapToSwitch,
                  KeyboardActivationState.active => l10n.playgroundActiveSubtitle,
                },
                style: const TextStyle(fontSize: 12),
              ),
              trailing: activationState == KeyboardActivationState.active
                  ? null
                  : TextButton(
                      onPressed: () async {
                        if (activationState == KeyboardActivationState.disabled) {
                          await ref.read(nativeBridgeProvider).openKeyboardSettings();
                        } else {
                          await ref.read(nativeBridgeProvider).showKeyboardPicker();
                        }
                        ref.invalidate(keyboardActivationStateProvider);
                      },
                      child: Text(
                        activationState == KeyboardActivationState.disabled
                            ? l10n.btnEnable
                            : l10n.btnSwitch,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (snippetCount == 0)
            Text(l10n.playgroundNoSnippets,
                textAlign: TextAlign.center),
          Text(
            l10n.playgroundPrefixDefault(AppLimits.defaultTriggerPrefix),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
