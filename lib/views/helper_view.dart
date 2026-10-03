import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/task_navigation.dart';
import '../core/helper/helper_chat_actions_parser.dart';
import '../core/input/keyboard.dart';
import '../core/road_guide/main_shell_metrics.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/helper_chat_action.dart';
import '../services/dialog_service.dart';
import '../services/helper_chat_action_service.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'common/app_alert_dialog.dart';
import 'common/context_menu_overlay.dart';
import 'common/helper_chat_sidebar.dart';
import 'common/themed_lottie.dart';
import 'edit_habit_view.dart';

class HelperView extends StatefulWidget {
  const HelperView({
    super.key,
    this.embedded = false,
    this.isActive = true,
    this.bottomBarClearance = kMainShellTabBarPreferredHeight,
  });

  static const routeName = '/helper';

  final bool embedded;

  /// When embedded in [MainShell], true while the Chat tab is selected.
  final bool isActive;

  /// Space reserved for the shell tab bar. Pass 0 when that bar is hidden.
  final double bottomBarClearance;

  @override
  State<HelperView> createState() => _HelperViewState();
}

class _HelperViewState extends State<HelperView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Lazy shell may mount this tab before it is selected; only hydrate when shown.
      if (widget.isActive) {
        context.read<HelperViewModel>().ensureLoaded();
      }
    });
  }

  @override
  void didUpdateWidget(HelperView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      context.read<HelperViewModel>().ensureLoaded();
    }
  }

  Future<void> _showHelperInfo(AppLocalizations l10n) {
    hideSoftKeyboard();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppAlertDialog.message(
        title: l10n.helperTitle,
        message: l10n.helperWarning,
        buttonLabel: l10n.okButton,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollChatToBottom({int attemptsLeft = 4}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        if (attemptsLeft > 0) {
          _scrollChatToBottom(attemptsLeft: attemptsLeft - 1);
        }
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(HelperViewModel vm, AppLocalizations l10n) async {
    final prompt = _controller.text;
    _controller.clear();
    hideSoftKeyboard();
    final pending = vm.ask(
      prompt,
      fallbackAnswer: l10n.chatFallbackAnswer,
      errorMessage: l10n.genericErrorOccurred,
    );
    // ask() notifies with the new turn before its first await.
    _scrollChatToBottom();
    await pending;
  }

  Widget _appBar(AppLocalizations l10n, {List<Widget>? extraActions}) {
    final vm = context.watch<HelperViewModel>();
    return GlassAppBar(
      title: Text(l10n.helperTitle),
      leading: GlassIconButton(
        icon: const Icon(Icons.menu),
        semanticLabel: l10n.helperOpenChats,
        onPressed: vm.toggleSidebar,
      ),
      actions: [
        GlassIconButton(
          icon: const Icon(Icons.info_outline),
          semanticLabel: l10n.helperTitle,
          onPressed: () => _showHelperInfo(l10n),
        ),
        ...?extraActions,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatBody = _HelperBody(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      onSend: _send,
    );

    if (widget.embedded) {
      // Sidebar wraps the whole tab (app bar + body) so it fills screen height.
      return HelperChatSidebarOverlay(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _appBar(l10n),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: widget.bottomBarClearance),
                  child: chatBody,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: _appBar(
        l10n,
        extraActions: [
          GlassIconButton(
            icon: const Icon(Icons.auto_awesome),
            semanticLabel: l10n.editHabitTitle,
            onPressed: () => EditHabitView.show(context),
          ),
        ],
      ),
      body: HelperChatSidebarOverlay(child: chatBody),
    );
  }
}

class _HelperBody extends StatelessWidget {
  const _HelperBody({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final Future<void> Function(HelperViewModel vm, AppLocalizations l10n) onSend;

  void _showCopiedToast(AppLocalizations l10n) {
    DialogService().showToast(l10n.successfulCopy);
  }

  Future<void> _copyText(AppLocalizations l10n, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: trimmed));
    _showCopiedToast(l10n);
  }

  void _showUserMessageMenu({
    required BuildContext context,
    required HelperViewModel vm,
    required AppLocalizations l10n,
    required int index,
    required ChatMessage message,
    Rect? anchor,
  }) {
    final palette = context.read<ThemeController>().palette;

    ContextMenuOverlay.show(
      context: context,
      builder: (dialogContext, animation) => ContextMenuOverlay(
        animation: animation,
        palette: palette,
        anchor: anchor,
        estimatedHeight: 100 + 52.0 * 2,
        child: Column(
          key: const Key('helperUserMessageContextMenu'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ContextMenuHeader(
              palette: palette,
              leading: ContextMenuLeadingIcon(
                icon: Icons.person_outline,
                palette: palette,
              ),
              title: message.text,
            ),
            const SizedBox(height: 12),
            ContextMenuActionList(
              palette: palette,
              actions: [
                ContextMenuAction(
                  label: l10n.habitMenuEdit,
                  icon: Icons.edit_outlined,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final text = await vm.prepareEditUserMessage(index);
                    if (text == null || !context.mounted) return;
                    controller.text = text;
                    controller.selection = TextSelection.collapsed(
                      offset: text.length,
                    );
                    focusNode.requestFocus();
                  },
                ),
                ContextMenuAction(
                  label: l10n.copyMessage,
                  icon: Icons.copy_outlined,
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await _copyText(l10n, message.text);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applySuggestedPrompt(
    HelperViewModel vm,
    AppLocalizations l10n,
    String prompt,
  ) {
    if (vm.isBusy || prompt.trim().isEmpty) return;
    controller.text = prompt;
    controller.selection = TextSelection.collapsed(offset: prompt.length);
    onSend(vm, l10n);
  }

  Future<void> _applyChatAction({
    required BuildContext context,
    required HelperViewModel vm,
    required ChatMessage message,
    required HelperChatAction action,
    required AppLocalizations l10n,
  }) async {
    if (message.appliedActionKeys.contains(action.dedupeKey)) return;

    final settings = context.read<SettingsViewModel>();
    if (action.type == HelperChatActionType.mission &&
        settings.mission.trim().isNotEmpty) {
      final ok = await DialogService().showConfirmAsync(
        title: l10n.helperActionReplaceMissionTitle,
        msg: l10n.helperActionReplaceMissionMessage,
      );
      if (!ok || !context.mounted) return;
    }
    if (action.type == HelperChatActionType.slogan &&
        settings.mainSlogan.trim().isNotEmpty) {
      final ok = await DialogService().showConfirmAsync(
        title: l10n.helperActionReplaceSloganTitle,
        msg: l10n.helperActionReplaceSloganMessage,
      );
      if (!ok || !context.mounted) return;
    }

    final applier = context.read<HelperChatActionService>();
    late final HelperChatActionApplyResult result;
    try {
      result = await applier.apply(action);
    } catch (_) {
      if (!context.mounted) return;
      DialogService().showToast(l10n.genericErrorOccurred);
      return;
    }
    if (!context.mounted) return;

    switch (result.kind) {
      case HelperChatActionApplyKind.empty:
        return;
      case HelperChatActionApplyKind.alreadyExists:
        vm.markActionApplied(message, action.dedupeKey);
        DialogService().showToast(l10n.helperActionAlreadyExists);
        return;
      case HelperChatActionApplyKind.openedDraft:
        final draft = result.taskDraft;
        if (draft == null) return;
        final saved = await TasksNavigation.openEditTask(
          context,
          aiDraft: draft,
        );
        if (!context.mounted) return;
        if (saved != null) {
          vm.markActionApplied(message, action.dedupeKey);
          await context.read<TasksViewModel>().load(silent: true);
          if (!context.mounted) return;
          DialogService().showToast(l10n.helperActionAdded);
        }
        return;
      case HelperChatActionApplyKind.created:
        vm.markActionApplied(message, action.dedupeKey);
        if (action.type == HelperChatActionType.goal) {
          await context.read<GoalsViewModel>().load(silent: true);
        } else if (action.type == HelperChatActionType.habit) {
          await context.read<HabitProgressViewModel>().load(silent: true);
        }
        if (!context.mounted) return;
        DialogService().showToast(l10n.helperActionAdded);
        return;
      case HelperChatActionApplyKind.updated:
        vm.markActionApplied(message, action.dedupeKey);
        await settings.loadProfile(silent: true);
        if (!context.mounted) return;
        DialogService().showToast(l10n.helperActionProfileUpdated);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final suggestedPrompts = <String>[
      l10n.helperPromptPersonality,
      l10n.helperPromptNextGoal,
      l10n.helperPromptStickHabits,
      l10n.helperPromptPlanToday,
    ];

    return Consumer<HelperViewModel>(
      builder: (context, vm, child) => Column(
        children: [
          Expanded(
            child: vm.messages.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const ThemedLottie(
                                    assetPath:
                                        'assets/lottie/emptychat_light.json',
                                    width: 220,
                                    height: 220,
                                  ),
                                  Text(
                                    l10n.helperEmptyDescription,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontSize: 18,
                                          height: 1.25,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    l10n.helperSuggestedPromptsTitle,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: palette.textMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    key: const Key('helperSuggestedPrompts'),
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (final prompt in suggestedPrompts)
                                        _HelperSuggestedPromptChip(
                                          label: prompt,
                                          enabled: !vm.isBusy,
                                          onTap: () => _applySuggestedPrompt(
                                            vm,
                                            l10n,
                                            prompt,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: vm.messages.length,
                    itemBuilder: (_, index) {
                      final msg = vm.messages[index];
                      final version = vm.versionOf(msg);
                      final versionSwitcher = version.count > 1
                          ? _HelperVersionSwitcher(
                              key: Key('helperVersionSwitcher:$index'),
                              index: version.index,
                              count: version.count,
                              enabled: vm.canSwitchVersion,
                              previousLabel: l10n.helperPreviousVersion,
                              nextLabel: l10n.helperNextVersion,
                              onSwitch: (delta) => vm.switchVersion(msg, delta),
                            )
                          : null;

                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            child: msg.isUser
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _HelperUserMessageBubble(
                                        message: msg,
                                        onLongPress: (anchor) {
                                          _showUserMessageMenu(
                                            context: context,
                                            vm: vm,
                                            l10n: l10n,
                                            index: index,
                                            message: msg,
                                            anchor: anchor,
                                          );
                                        },
                                      ),
                                      ?versionSwitcher,
                                    ],
                                  )
                                : _HelperAiMessageBubble(
                                    message: msg,
                                    copyLabel: l10n.copyMessage,
                                    retryLabel: l10n.retryButton,
                                    versionSwitcher: versionSwitcher,
                                    onCopied: () => _showCopiedToast(l10n),
                                    onRetry: vm.canRetry(msg)
                                        ? () => vm.retryAnswer(
                                            msg,
                                            fallbackAnswer:
                                                l10n.chatFallbackAnswer,
                                            errorMessage:
                                                l10n.genericErrorOccurred,
                                          )
                                        : null,
                                    onApplyAction: (action) => _applyChatAction(
                                      context: context,
                                      vm: vm,
                                      message: msg,
                                      action: action,
                                      l10n: l10n,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (vm.isEditing)
            Padding(
              key: const Key('helperEditingBanner'),
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: palette.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.helperEditingMessage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('helperCancelEdit'),
                    onPressed: () {
                      controller.clear();
                      vm.cancelEdit();
                    },
                    tooltip: l10n.cancelButton,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 20, color: palette.textMuted),
                  ),
                ],
              ),
            ),
          Padding(
            key: context.read<RoadGuideController>().keys.chatInput,
            // Bottom pad is small; [bottomBarClearance] owns the gap to the pill.
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  // GlassTextField does not expose textCapitalization; on iOS
                  // that defaults to none (lowercase keyboard). Build the same
                  // glass surface with CupertinoTextField so sentences capitalize.
                  child: AdaptiveGlass(
                    useOwnLayer: true,
                    shape: const LiquidRoundedRectangle(borderRadius: 10),
                    settings: const LiquidGlassSettings(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: CupertinoTextField(
                        key: const Key('helperChatInput'),
                        controller: controller,
                        focusNode: focusNode,
                        placeholder: l10n.helperInputHint,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(vm, l10n),
                        padding: EdgeInsets.zero,
                        decoration: null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icon(
                    vm.isBusy ? Icons.stop_circle_outlined : Icons.send,
                  ),
                  onPressed: vm.isBusy ? vm.cancel : () => onSend(vm, l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelperSuggestedPromptChip extends StatelessWidget {
  const _HelperSuggestedPromptChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('helperSuggestedPrompt:$label'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.softBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// User prompt bubble: long-press opens Edit / Copy context menu.
class _HelperUserMessageBubble extends StatelessWidget {
  const _HelperUserMessageBubble({
    required this.message,
    required this.onLongPress,
  });

  final ChatMessage message;
  final ValueChanged<Rect?> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        Rect? anchor;
        if (box != null && box.hasSize) {
          anchor = box.localToGlobal(Offset.zero) & box.size;
        }
        onLongPress(anchor);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message.text,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// `‹ 2/3 ›` pager between versions of an edited prompt or retried reply.
class _HelperVersionSwitcher extends StatelessWidget {
  const _HelperVersionSwitcher({
    super.key,
    required this.index,
    required this.count,
    required this.enabled,
    required this.previousLabel,
    required this.nextLabel,
    required this.onSwitch,
  });

  final int index;
  final int count;
  final bool enabled;
  final String previousLabel;
  final String nextLabel;
  final ValueChanged<int> onSwitch;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);

    Widget chevron(IconData icon, String label, int delta, bool canGo) {
      final active = enabled && canGo;
      return IconButton(
        onPressed: active ? () => onSwitch(delta) : null,
        tooltip: label,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 20,
          color: active ? color : color.withValues(alpha: 0.15),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chevron(Icons.chevron_left, previousLabel, -1, index > 1),
        Text(
          '$index/$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        chevron(Icons.chevron_right, nextLabel, 1, index < count),
      ],
    );
  }
}

/// AI reply bubble: selectable body for partial copy; copy icon for full text.
class _HelperAiMessageBubble extends StatelessWidget {
  const _HelperAiMessageBubble({
    required this.message,
    required this.copyLabel,
    required this.retryLabel,
    required this.versionSwitcher,
    required this.onCopied,
    required this.onRetry,
    required this.onApplyAction,
  });

  final ChatMessage message;
  final String copyLabel;
  final String retryLabel;
  final Widget? versionSwitcher;
  final VoidCallback onCopied;

  /// Null hides the retry button (only the latest reply can be regenerated).
  final VoidCallback? onRetry;
  final ValueChanged<HelperChatAction> onApplyAction;

  Future<void> _copyAll() async {
    final text = helperChatDisplayText(message.text).trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    onCopied();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final parsed = parseHelperChatActions(
      message.text,
      parseActions: message.isComplete,
    );
    final displayText = parsed.displayText;
    final showActions = message.isComplete && parsed.actions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayText.trim().isNotEmpty)
          GlassCard(
            useOwnLayer: true,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              displayText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (showActions) ...[
          const SizedBox(height: 8),
          for (final action in parsed.actions) ...[
            _HelperActionCard(
              palette: palette,
              action: action,
              applied: message.appliedActionKeys.contains(action.dedupeKey),
              actionLabel: _actionLabel(l10n, action.type),
              onApply: () => onApplyAction(action),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (message.isComplete && displayText.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?versionSwitcher,
                if (onRetry != null)
                  IconButton(
                    key: const Key('helperRetryAnswer'),
                    onPressed: onRetry,
                    tooltip: retryLabel,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.refresh, size: 20, color: iconColor),
                  ),
                IconButton(
                  onPressed: _copyAll,
                  tooltip: copyLabel,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.copy_outlined, size: 20, color: iconColor),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _actionLabel(AppLocalizations l10n, HelperChatActionType type) {
    return switch (type) {
      HelperChatActionType.goal => l10n.helperActionAddGoal,
      HelperChatActionType.habit => l10n.helperActionAddHabit,
      HelperChatActionType.task => l10n.helperActionAddTask,
      HelperChatActionType.mission => l10n.helperActionSetMission,
      HelperChatActionType.slogan => l10n.helperActionSetSlogan,
    };
  }
}

class _HelperActionCard extends StatelessWidget {
  const _HelperActionCard({
    required this.palette,
    required this.action,
    required this.applied,
    required this.actionLabel,
    required this.onApply,
  });

  final TasksUiPalette palette;
  final HelperChatAction action;
  final bool applied;
  final String actionLabel;
  final VoidCallback onApply;

  IconData get _icon => switch (action.type) {
    HelperChatActionType.goal => Icons.flag_outlined,
    HelperChatActionType.habit => Icons.replay_circle_filled_outlined,
    HelperChatActionType.task => Icons.check_circle_outline,
    HelperChatActionType.mission => Icons.explore_outlined,
    HelperChatActionType.slogan => Icons.format_quote_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final subtitle = action.reason.trim().isNotEmpty
        ? action.reason.trim()
        : (action.goalName?.trim().isNotEmpty == true
              ? action.goalName!.trim()
              : '');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.primary.withValues(
            alpha: palette.isDark ? 0.35 : 0.22,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: palette.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: applied ? null : onApply,
            child: Text(
              applied
                  ? AppLocalizations.of(context)!.helperActionAdded
                  : actionLabel,
            ),
          ),
        ],
      ),
    );
  }
}
