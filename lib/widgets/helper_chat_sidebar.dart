import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/ai_conversation.dart';
import '../viewmodels/helper_viewmodel.dart';
import 'app_alert_dialog.dart';

/// ChatGPT-style left sidebar listing persisted AI Helper conversations.
class HelperChatSidebar extends StatelessWidget {
  const HelperChatSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final vm = context.watch<HelperViewModel>();

    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.helperChatsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                onChanged: vm.setSearchQuery,
                decoration: InputDecoration(
                  hintText: l10n.helperSearchChatsHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Expanded(
              child: vm.filteredConversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.helperNoChats,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: vm.filteredConversations.length,
                      itemBuilder: (context, index) {
                        final chat = vm.filteredConversations[index];
                        return _ChatTile(
                          conversation: chat,
                          selected: chat.id == vm.activeConversationId,
                          untitledLabel: l10n.helperUntitledChat,
                          deleteLabel: l10n.deleteTooltip,
                          onOpen: () => vm.openConversation(chat.id),
                          onDelete: () =>
                              _confirmDelete(context, vm, l10n, chat),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => vm.startNewChat(),
                  icon: const Icon(Icons.edit_square, size: 20),
                  label: Text(l10n.helperNewChat),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HelperViewModel vm,
    AppLocalizations l10n,
    AiConversation chat,
  ) async {
    final title = chat.title.trim().isEmpty
        ? l10n.helperUntitledChat
        : chat.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog.confirm(
        title: l10n.deleteTooltip,
        message: title,
        cancelLabel: l10n.noButton,
        confirmLabel: l10n.yesButton,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed == true) {
      await vm.deleteConversation(chat.id);
    }
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.conversation,
    required this.selected,
    required this.untitledLabel,
    required this.deleteLabel,
    required this.onOpen,
    required this.onDelete,
  });

  final AiConversation conversation;
  final bool selected;
  final String untitledLabel;
  final String deleteLabel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = conversation.title.trim().isEmpty
        ? untitledLabel
        : conversation.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: deleteLabel,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-bleed overlay that slides the [HelperChatSidebar] from the left.
///
/// Fills the parent height (typically the whole Helper tab) so the drawer is
/// edge-to-edge; the shell hides the tab bar while the sidebar is open.
class HelperChatSidebarOverlay extends StatelessWidget {
  const HelperChatSidebarOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HelperViewModel>();
    final width = MediaQuery.sizeOf(context).width * 0.82;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (vm.sidebarOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => vm.setSidebarOpen(false),
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width.clamp(260.0, 360.0),
            child: const HelperChatSidebar(),
          ),
        ],
      ],
    );
  }
}
