import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/profile_text_suggestion.dart';
import '../services/ai_recommendation_service.dart';
import '../services/goal_service.dart';
import '../services/user_service.dart';
import '../viewmodels/edit_profile_text_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'common/app_liquid_background.dart';

/// Dedicated page for editing the main slogan (Settings → Main slogan).
class EditSloganView extends StatelessWidget {
  const EditSloganView({
    super.key,
    this.initialText,
    this.draftMode = false,
    this.draftGender,
  });

  static const routeName = '/edit-slogan';

  final String? initialText;
  final bool draftMode;
  final int? draftGender;

  static Future<bool> open(BuildContext context) {
    final initial = context.read<SettingsViewModel>().mainSlogan;
    return Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            settings: const RouteSettings(name: routeName),
            builder: (_) => EditSloganView(initialText: initial),
          ),
        )
        .then((saved) => saved ?? false);
  }

  /// Opens a draft editor for signup (no profile save). Returns confirmed text
  /// or `null` if the user backs out.
  static Future<String?> openDraft(
    BuildContext context, {
    String initialText = '',
    int? gender,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => EditSloganView(
          initialText: initialText,
          draftMode: true,
          draftGender: gender,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = initialText ?? _readInitial(context, isMission: false);
    return EditProfileTextView(
      kind: ProfileTextKind.slogan,
      initialText: resolved,
      draftMode: draftMode,
      draftGender: draftGender,
    );
  }
}

/// Dedicated page for editing the mission (Settings → Mission).
class EditMissionView extends StatelessWidget {
  const EditMissionView({
    super.key,
    this.initialText,
    this.draftMode = false,
    this.draftGender,
  });

  static const routeName = '/edit-mission';

  final String? initialText;
  final bool draftMode;
  final int? draftGender;

  static Future<bool> open(BuildContext context) {
    final initial = context.read<SettingsViewModel>().mission;
    return Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            settings: const RouteSettings(name: routeName),
            builder: (_) => EditMissionView(initialText: initial),
          ),
        )
        .then((saved) => saved ?? false);
  }

  /// Opens a draft editor for signup (no profile save). Returns confirmed text
  /// or `null` if the user backs out.
  static Future<String?> openDraft(
    BuildContext context, {
    String initialText = '',
    int? gender,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => EditMissionView(
          initialText: initialText,
          draftMode: true,
          draftGender: gender,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = initialText ?? _readInitial(context, isMission: true);
    return EditProfileTextView(
      kind: ProfileTextKind.mission,
      initialText: resolved,
      draftMode: draftMode,
      draftGender: draftGender,
    );
  }
}

String _readInitial(BuildContext context, {required bool isMission}) {
  try {
    final settings = context.read<SettingsViewModel>();
    return isMission ? settings.mission : settings.mainSlogan;
  } catch (_) {
    return '';
  }
}

class EditProfileTextView extends StatefulWidget {
  const EditProfileTextView({
    super.key,
    required this.kind,
    required this.initialText,
    this.draftMode = false,
    this.draftGender,
  });

  final ProfileTextKind kind;
  final String initialText;
  final bool draftMode;
  final int? draftGender;

  @override
  State<EditProfileTextView> createState() => _EditProfileTextViewState();
}

class _EditProfileTextViewState extends State<EditProfileTextView> {
  late final EditProfileTextViewModel _vm;
  late final TextEditingController _textController;
  late final TextEditingController _hintController;
  bool _allowPop = false;
  Object? _popResult;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    GoalService? goals;
    UserService? users;
    AiRecommendationService? ai;
    try {
      goals = context.read<GoalService>();
    } catch (_) {
      goals = null;
    }
    try {
      users = context.read<UserService>();
    } catch (_) {
      users = null;
    }
    try {
      ai = context.read<AiRecommendationService>();
    } catch (_) {
      ai = null;
    }
    _vm = EditProfileTextViewModel(
      kind: widget.kind,
      userService: users,
      aiRecommendationService: ai,
      goalService: goals,
      draftMode: widget.draftMode,
      draftGender: widget.draftGender,
      initialText: widget.initialText,
    );
    _textController = TextEditingController(text: _vm.text);
    _hintController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _hintController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _leave({Object? result}) async {
    if (_leaving || _allowPop) return;
    _leaving = true;
    if (!mounted) return;
    setState(() {
      _allowPop = true;
      _popResult = result;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_popResult);
    });
  }

  Future<void> _save() async {
    _vm.updateText(_textController.text);
    final l10n = AppLocalizations.of(context)!;

    if (widget.draftMode) {
      final text = _vm.confirmDraft();
      await _leave(result: text);
      return;
    }

    final ok = await _vm.save();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.error ?? l10n.genericErrorOccurred)),
      );
      return;
    }
    final message = widget.kind == ProfileTextKind.mission
        ? l10n.missionSavedSuccess
        : l10n.sloganSavedSuccess;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    try {
      await context.read<SettingsViewModel>().loadProfile(silent: true);
    } catch (_) {}
    if (!mounted) return;
    await _leave(result: true);
  }

  Future<void> _suggest() async {
    _vm.updateText(_textController.text);
    _vm.updateHint(_hintController.text);
    await _vm.suggestWithAi(
      culture: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    final isMission = widget.kind == ProfileTextKind.mission;
    final title = isMission ? l10n.yourMission : l10n.yourMainSlogan;
    final explanation = isMission
        ? l10n.missionExplanation
        : l10n.mainSloganExplanation;
    final subtitle = isMission
        ? l10n.missionPageSubtitle
        : l10n.sloganPageSubtitle;
    final fieldLabel = isMission ? l10n.missionLabel : l10n.sloganLabel;
    final icon = isMission ? Icons.flag_rounded : Icons.auto_awesome_rounded;
    final showAi = _vm.canSuggestWithAi && !widget.draftMode;
    final confirmLabel = widget.draftMode ? l10n.doneButton : l10n.saveButton;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _leave();
          },
          child: GlassScaffold(
            background: const AppLiquidBackground(),
            extendBody: false,
            appBar: GlassAppBar(
              title: Text(title),
              leading: GlassIconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => _leave(),
              ),
            ),
            body: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _HeroCard(
                          palette: palette,
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                          explanation: explanation,
                          learnMoreLabel: l10n.profileTextLearnMore,
                        ),
                        const SizedBox(height: 18),
                        _EditorCard(
                          palette: palette,
                          fieldLabel: fieldLabel,
                          textController: _textController,
                          hintController: _hintController,
                          maxLines: isMission ? 7 : 5,
                          onTextChanged: _vm.updateText,
                          onHintChanged: _vm.updateHint,
                          hintLabel: l10n.profileTextHintLabel,
                          hintPlaceholder: l10n.profileTextHintPlaceholder,
                          showAiHint: showAi,
                        ),
                        if (showAi) ...[
                          const SizedBox(height: 16),
                          _AiSuggestButton(
                            palette: palette,
                            isLoading: _vm.isSuggesting,
                            label: l10n.suggestWithAiButton,
                            loadingHint: l10n.profileTextAiLoadingHint,
                            onPressed: _vm.isSaving ? null : _suggest,
                          ),
                          if (_vm.suggestError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _vm.suggestError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (_vm.suggestions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              l10n.profileTextSuggestionsTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            for (
                              var i = 0;
                              i < _vm.suggestions.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _SuggestionCard(
                                palette: palette,
                                suggestion: _vm.suggestions[i],
                                useLabel: l10n.profileTextApplySuggestion,
                                onApply: () {
                                  _vm.applySuggestion(_vm.suggestions[i]);
                                  _textController.text = _vm.text;
                                  _textController.selection =
                                      TextSelection.collapsed(
                                        offset: _textController.text.length,
                                      );
                                },
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                  _SaveBar(
                    palette: palette,
                    isSaving: _vm.isSaving,
                    label: confirmLabel,
                    onSave: _vm.isSuggesting ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.learnMoreLabel,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final String explanation;
  final String learnMoreLabel;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: palette.cardBorder.withValues(
                alpha: palette.isDark ? 0.45 : 0.7,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(
                  alpha: palette.isDark ? 0.22 : 0.10,
                ),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(gradient: palette.primaryGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: palette.onPrimary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: palette.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: palette.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: palette.onPrimary.withValues(alpha: 0.92),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: palette.cardBg,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _expanded
                                    ? widget.explanation
                                    : widget.learnMoreLabel,
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 13.5,
                                  height: 1.4,
                                  fontWeight: _expanded
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: palette.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.palette,
    required this.fieldLabel,
    required this.textController,
    required this.hintController,
    required this.maxLines,
    required this.onTextChanged,
    required this.onHintChanged,
    required this.hintLabel,
    required this.hintPlaceholder,
    this.showAiHint = true,
  });

  final TasksUiPalette palette;
  final String fieldLabel;
  final TextEditingController textController;
  final TextEditingController hintController;
  final int maxLines;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onHintChanged;
  final String hintLabel;
  final String hintPlaceholder;
  final bool showAiHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: palette.cardBorder.withValues(
            alpha: palette.isDark ? 0.4 : 0.65,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fieldLabel,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('editProfileTextInput'),
            controller: textController,
            onChanged: onTextChanged,
            maxLines: maxLines,
            minLines: 3,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.softBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            ),
          ),
          if (showAiHint) ...[
            const SizedBox(height: 16),
            Text(
              hintLabel,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: TextField(
                key: const Key('editProfileTextHintInput'),
                controller: hintController,
                onChanged: onHintChanged,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: hintPlaceholder,
                  filled: true,
                  fillColor: palette.softBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  prefixIcon: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: palette.primary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiSuggestButton extends StatelessWidget {
  const _AiSuggestButton({
    required this.palette,
    required this.isLoading,
    required this.label,
    required this.loadingHint,
    required this.onPressed,
  });

  final TasksUiPalette palette;
  final bool isLoading;
  final String label;
  final String loadingHint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('editProfileTextSuggestButton'),
          height: 50,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  )
                : Icon(Icons.auto_awesome, color: palette.primary),
            label: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: palette.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        if (isLoading) ...[
          const SizedBox(height: 8),
          Text(
            loadingHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.palette,
    required this.suggestion,
    required this.useLabel,
    required this.onApply,
  });

  final TasksUiPalette palette;
  final ProfileTextSuggestion suggestion;
  final String useLabel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('editProfileTextSuggestion_${suggestion.text.hashCode}'),
        onTap: onApply,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: palette.cardBorder.withValues(
                alpha: palette.isDark ? 0.4 : 0.65,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.format_quote_rounded,
                  color: palette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.text,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (suggestion.reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        suggestion.reason,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      useLabel,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.palette,
    required this.isSaving,
    required this.label,
    required this.onSave,
  });

  final TasksUiPalette palette;
  final bool isSaving;
  final String label;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('editProfileTextSaveButton'),
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: palette.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
