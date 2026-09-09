import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/road_guide/road_guide_controller.dart';
import '../core/theme/theme_controller.dart';
import '../services/dialog_service.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/context_menu_overlay.dart';
import '../widgets/helper_chat_sidebar.dart';
import '../widgets/themed_lottie.dart';
import 'edit_habit_view.dart';

class HelperView extends StatefulWidget {
  const HelperView({
    super.key,
    this.embedded = false,
    this.bottomBarClearance = 80,
  });

  static const routeName = '/helper';

  final bool embedded;

  /// Space reserved for the shell tab bar. Pass 0 when that bar is hidden.
  final double bottomBarClearance;

  @override
  State<HelperView> createState() => _HelperViewState();
}

class _HelperViewState extends State<HelperView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HelperViewModel>().ensureLoaded();
    });
  }

  Future<void> _showHelperInfo(AppLocalizations l10n) {
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
    super.dispose();
  }

  Future<void> _send(HelperViewModel vm, AppLocalizations l10n) async {
    final prompt = _controller.text;
    _controller.clear();
    await vm.ask(
      prompt,
      fallbackAnswer: l10n.chatFallbackAnswer,
      errorMessage: l10n.genericErrorOccurred,
    );
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
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: vm.messages.length,
                    itemBuilder: (_, index) {
                      final msg = vm.messages[index];

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
                                ? _HelperUserMessageBubble(
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
                                  )
                                : _HelperAiMessageBubble(
                                    message: msg,
                                    copyLabel: l10n.copyMessage,
                                    onCopied: () => _showCopiedToast(l10n),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            key: context.read<RoadGuideController>().keys.chatInput,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    useOwnLayer: true,
                    controller: controller,
                    focusNode: focusNode,
                    placeholder: l10n.helperInputHint,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(vm, l10n),
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

/// AI reply bubble: selectable body for partial copy; copy icon for full text.
class _HelperAiMessageBubble extends StatelessWidget {
  const _HelperAiMessageBubble({
    required this.message,
    required this.copyLabel,
    required this.onCopied,
  });

  final ChatMessage message;
  final String copyLabel;
  final VoidCallback onCopied;

  Future<void> _copyAll() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    onCopied();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          useOwnLayer: true,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (message.isComplete && message.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: IconButton(
              onPressed: _copyAll,
              tooltip: copyLabel,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.copy_outlined, size: 20, color: iconColor),
            ),
          ),
      ],
    );
  }
}
