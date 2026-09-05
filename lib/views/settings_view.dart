import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/launch_data_loader.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/ui_theme_switcher.dart';
import 'forget_password_view.dart';
import 'startup_view.dart';

/// Shared insets for settings cards — ListView already pads horizontally.
const _settingsSectionMargin = EdgeInsets.symmetric(vertical: 4);
const _settingsTilePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.embedded = false});

  static const routeName = '/settings';

  final bool embedded;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    // Embedded shell used to skip load(); after Google/Apple login the splash
    // LaunchDataLoader often finished pre-auth and never hydrated profile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsViewModel>().load(silent: widget.embedded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _SettingsBody(embedded: widget.embedded);

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(title: Text(l10n.settingsTitle)),
            Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.settingsTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: body,
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = embedded
        ? MediaQuery.paddingOf(context).bottom + 124
        : 24.0;

    return Material(
      type: MaterialType.transparency,
      child: Consumer<SettingsViewModel>(
        builder: (context, vm, child) {
          final guide = context.read<RoadGuideController>();
          return ListView(
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
            children: [
              KeyedSubtree(
                key: guide.keys.settingsProfile,
                child: GlassGroupedSection(
                  useOwnLayer: true,
                  margin: _settingsSectionMargin,
                  header: Text(l10n.settingsSectionProfile),
                  children: [
                    if (vm.isLoadingProfile)
                      const AppLoadingIndicator(
                        size: 72,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      )
                    else if (vm.isSavingProfile || vm.isDeletingAccount)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: LinearProgressIndicator(),
                      ),
                    GlassListTile(
                      key: const Key('settingsProfileNameTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.person_outline),
                      title: Text(l10n.nameLabel),
                      subtitle: Text(
                        vm.userName.isEmpty ? l10n.optionalLabel : vm.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: GlassListTile.chevron,
                      onTap: () => _editName(context, vm, l10n),
                    ),
                    GlassListTile(
                      key: const Key('settingsProfileEmailTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.mail_outline),
                      title: Text(l10n.emailLabel),
                      subtitle: Text(
                        vm.email.isEmpty ? l10n.optionalLabel : vm.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _showEmailNotEditable(context, l10n),
                    ),
                    GlassListTile(
                      key: const Key('settingsProfileGenderTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.wc_outlined),
                      title: Text(l10n.genderLabel),
                      subtitle: Text(
                        _genderName(l10n, vm.gender),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: GlassListTile.chevron,
                      onTap: () => _editGender(context, vm, l10n),
                    ),
                    GlassListTile(
                      key: const Key('settingsProfileSloganTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(l10n.sloganLabel),
                      subtitle: Text(
                        vm.mainSlogan.isEmpty
                            ? l10n.optionalLabel
                            : vm.mainSlogan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: GlassListTile.chevron,
                      onTap: () => _editSlogan(context, vm, l10n),
                    ),
                    GlassListTile(
                      key: const Key('settingsProfileMissionTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(l10n.missionLabel),
                      subtitle: Text(
                        vm.mission.isEmpty ? l10n.optionalLabel : vm.mission,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: GlassListTile.chevron,
                      onTap: () => _editMission(context, vm, l10n),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassGroupedSection(
                useOwnLayer: true,
                margin: _settingsSectionMargin,
                header: Text(l10n.themeLabel),
                children: [
                  GlassListTile(
                    key: const Key('settingsThemeTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(l10n.themeLabel),
                    subtitle: Text(
                      l10n.themeSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const AppThemeSwitcher(compact: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassGroupedSection(
                useOwnLayer: true,
                margin: _settingsSectionMargin,
                header: Text(l10n.languageLabel),
                children: [
                  GlassListTile(
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.language_outlined),
                    title: Text(l10n.languageLabel),
                    subtitle: Text(
                      l10n.languageSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: l10n.languageLabel,
                      onSelected: (value) {
                        vm.setLocaleOverride(switch (value) {
                          'en' => const Locale('en'),
                          'uk' => const Locale('uk'),
                          _ => null,
                        });
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'system',
                          child: Text(l10n.languageSystem),
                        ),
                        PopupMenuItem<String>(
                          value: 'en',
                          child: Text(l10n.languageEnglish),
                        ),
                        PopupMenuItem<String>(
                          value: 'uk',
                          child: Text(l10n.languageUkrainian),
                        ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              _languageName(l10n, vm.localeOverride),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassGroupedSection(
                useOwnLayer: true,
                margin: _settingsSectionMargin,
                header: Text(l10n.settingsSectionAbout),
                children: [
                  GlassListTile(
                    key: context
                        .read<RoadGuideController>()
                        .keys
                        .settingsReplay,
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.tour_outlined),
                    title: Text(l10n.roadGuideReplayLabel),
                    subtitle: Text(
                      l10n.roadGuideReplaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: GlassListTile.chevron,
                    onTap: () {
                      context.read<RoadGuideController>().start(
                        markAsReplay: true,
                      );
                    },
                  ),
                  GlassListTile(
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.aboutProgram),
                    trailing: GlassListTile.chevron,
                    onTap: vm.openAboutSite,
                  ),
                  GlassListTile(
                    key: const Key('settingsTelegramTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.telegram),
                    title: Text(l10n.joinTelegramLabel),
                    trailing: GlassListTile.chevron,
                    onTap: vm.openTelegramChannel,
                  ),
                  if (!kIsWeb)
                    GlassListTile(
                      key: const Key('settingsRateUsTile'),
                      contentPadding: _settingsTilePadding,
                      leading: const Icon(Icons.star_outline),
                      title: Text(l10n.rateUsLabel),
                      trailing: GlassListTile.chevron,
                      onTap: vm.rateApp,
                    ),
                  GlassListTile(
                    key: const Key('settingsShareAppTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.share_outlined),
                    title: Text(l10n.shareAppLabel),
                    trailing: GlassListTile.chevron,
                    onTap: () => vm.shareApp(l10n.shareAppMessage),
                  ),
                  GlassListTile(
                    key: const Key('settingsContactEmailTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.email_outlined),
                    title: Text(l10n.contactEmailLabel),
                    subtitle: Text(
                      l10n.contactEmailSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: GlassListTile.chevron,
                    onTap: () => _openContactEmail(context, vm, l10n),
                  ),
                  GlassListTile(
                    key: const Key('settingsPrivacyPolicyTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l10n.settingsPrivacyPolicy),
                    trailing: GlassListTile.chevron,
                    onTap: vm.openPrivacyPolicy,
                  ),
                  GlassListTile(
                    key: const Key('settingsUserAgreementTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.settingsUserAgreement),
                    trailing: GlassListTile.chevron,
                    onTap: vm.openUserAgreement,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassGroupedSection(
                useOwnLayer: true,
                margin: _settingsSectionMargin,
                header: Text(l10n.settingsSectionAccount),
                children: [
                  GlassListTile(
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.changePasswordLabel),
                    trailing: GlassListTile.chevron,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        ForgetPasswordView.routeName,
                        arguments: vm.email.isEmpty ? null : vm.email,
                      );
                    },
                  ),
                  GlassListTile(
                    key: const Key('settingsLogoutTile'),
                    contentPadding: _settingsTilePadding,
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.logoutLabel),
                    onTap: () => _logout(context, vm),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassGroupedSection(
                useOwnLayer: true,
                margin: _settingsSectionMargin,
                children: [
                  GlassListTile(
                    key: const Key('settingsDeleteAccountTile'),
                    contentPadding: _settingsTilePadding,
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n.deleteAccountLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => _deleteAccount(context, vm, l10n),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _languageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;
    return switch (locale.languageCode) {
      'uk' => l10n.languageUkrainian,
      'en' => l10n.languageEnglish,
      _ => l10n.languageSystem,
    };
  }

  String _genderName(AppLocalizations l10n, int gender) {
    return switch (gender) {
      1 => l10n.genderFemale,
      2 => l10n.genderOther,
      _ => l10n.genderMale,
    };
  }

  Future<void> _editName(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final result = await _showProfileEditor(
      context: context,
      title: l10n.yourName,
      initialValue: vm.userName,
      maxLines: 1,
      requiredField: true,
      requiredMessage: l10n.fieldRequired,
      l10n: l10n,
    );
    if (result == null || !context.mounted) return;
    final saved = await vm.saveUserName(result);
    if (!context.mounted) return;
    _showSaveResult(
      context,
      saved
          ? l10n.nameSavedSuccess
          : (vm.profileError ?? l10n.genericErrorOccurred),
    );
  }

  Future<void> _editGender(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _GenderEditDialog(
        title: l10n.yourGender,
        initialValue: vm.gender,
        l10n: l10n,
      ),
    );
    if (result == null || !context.mounted) return;
    if (result == vm.gender) return;
    final saved = await vm.saveGender(result);
    if (!context.mounted) return;
    _showSaveResult(
      context,
      saved
          ? l10n.genderSavedSuccess
          : (vm.profileError ?? l10n.genericErrorOccurred),
    );
  }

  Future<void> _editSlogan(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final result = await _showProfileEditor(
      context: context,
      title: l10n.yourMainSlogan,
      initialValue: vm.mainSlogan,
      maxLines: 5,
      explanation: l10n.mainSloganExplanation,
      l10n: l10n,
    );
    if (result == null || !context.mounted) return;
    final saved = await vm.saveMainSlogan(result);
    if (!context.mounted) return;
    _showSaveResult(
      context,
      saved
          ? l10n.sloganSavedSuccess
          : (vm.profileError ?? l10n.genericErrorOccurred),
    );
  }

  Future<void> _editMission(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final result = await _showProfileEditor(
      context: context,
      title: l10n.yourMission,
      initialValue: vm.mission,
      maxLines: 7,
      explanation: l10n.missionExplanation,
      l10n: l10n,
    );
    if (result == null || !context.mounted) return;
    final saved = await vm.saveMission(result);
    if (!context.mounted) return;
    _showSaveResult(
      context,
      saved
          ? l10n.missionSavedSuccess
          : (vm.profileError ?? l10n.genericErrorOccurred),
    );
  }

  Future<void> _showEmailNotEditable(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppAlertDialog.message(
        title: l10n.emailLabel,
        message: l10n.fieldIsNotEditable,
        buttonLabel: l10n.okButton,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _openContactEmail(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final launched = await vm.openContactEmail();
    if (launched || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppAlertDialog.message(
        title: l10n.errorTitle,
        message: l10n.cannotOpenEmailApp,
        buttonLabel: l10n.okButton,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _logout(BuildContext context, SettingsViewModel vm) async {
    await vm.logout();
    if (!context.mounted) return;
    _clearInMemorySessionState(context);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: StartupView.routeName),
        builder: (_) => const StartupView(showAuthenticationImmediately: true),
      ),
      (route) => false,
    );
  }

  void _clearInMemorySessionState(BuildContext context) {
    try {
      context.read<GoalsViewModel>().clear();
    } catch (_) {}
    try {
      context.read<TasksViewModel>().clear();
    } catch (_) {}
    try {
      context.read<HabitProgressViewModel>().clear();
    } catch (_) {}
    try {
      context.read<LaunchDataLoader>().reset();
    } catch (_) {}
  }

  Future<void> _deleteAccount(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog.confirm(
        title: l10n.deleteAccountQuestion,
        message: l10n.deleteAccountConfirm,
        cancelLabel: l10n.noButton,
        confirmLabel: l10n.yesButton,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await vm.deleteAccount();
    if (!context.mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.profileError ?? l10n.genericErrorOccurred)),
      );
      return;
    }
    await _logout(context, vm);
  }

  void _showSaveResult(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<String?> _showProfileEditor({
  required BuildContext context,
  required String title,
  required String initialValue,
  required AppLocalizations l10n,
  int maxLines = 1,
  bool requiredField = false,
  String? requiredMessage,
  String? explanation,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ProfileEditDialog(
      title: title,
      initialValue: initialValue,
      maxLines: maxLines,
      requiredField: requiredField,
      requiredMessage: requiredMessage,
      explanation: explanation,
      l10n: l10n,
    ),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({
    required this.title,
    required this.initialValue,
    required this.maxLines,
    required this.requiredField,
    required this.l10n,
    this.requiredMessage,
    this.explanation,
  });

  final String title;
  final String initialValue;
  final int maxLines;
  final bool requiredField;
  final String? requiredMessage;
  final String? explanation;
  final AppLocalizations l10n;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _controller;
  final GlobalKey _explanationKey = GlobalKey();
  bool _showExplanation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExplanation() {
    final showing = !_showExplanation;
    setState(() => _showExplanation = showing);
    if (!showing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final explanationContext = _explanationKey.currentContext;
      if (explanationContext == null) return;
      Scrollable.ensureVisible(
        explanationContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _submit() {
    final value = _controller.text;
    if (widget.requiredField && value.trim().isEmpty) {
      setState(() => _error = widget.requiredMessage);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keep the field+explanation scrollable above the keyboard / actions.
    final contentMaxHeight =
        (media.size.height -
                media.viewInsets.bottom -
                media.padding.vertical -
                220)
            .clamp(140.0, 360.0);

    return AppAlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: contentMaxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('settingsProfileFieldInput'),
                controller: _controller,
                autofocus: true,
                maxLines: widget.maxLines,
                textInputAction: widget.maxLines == 1
                    ? TextInputAction.done
                    : TextInputAction.newline,
                onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
                decoration: InputDecoration(
                  errorText: _error,
                  suffixIcon: widget.explanation == null
                      ? null
                      : IconButton(
                          key: const Key('settingsProfileFieldInfo'),
                          icon: const Icon(Icons.info_outline),
                          onPressed: _toggleExplanation,
                        ),
                ),
              ),
              if (_showExplanation && widget.explanation != null) ...[
                const SizedBox(height: 12),
                Text(
                  key: _explanationKey,
                  widget.explanation!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancelButton),
        ),
        TextButton(
          key: const Key('settingsProfileFieldSave'),
          onPressed: _submit,
          child: Text(widget.l10n.saveButton),
        ),
      ],
    );
  }
}

class _GenderEditDialog extends StatefulWidget {
  const _GenderEditDialog({
    required this.title,
    required this.initialValue,
    required this.l10n,
  });

  final String title;
  final int initialValue;
  final AppLocalizations l10n;

  @override
  State<_GenderEditDialog> createState() => _GenderEditDialogState();
}

class _GenderEditDialogState extends State<_GenderEditDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final options = <(int, String)>[
      (0, widget.l10n.genderMale),
      (1, widget.l10n.genderFemale),
      (2, widget.l10n.genderOther),
    ];

    return AppAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            RadioListTile<int>(
              key: Key('settingsGenderOption_${option.$1}'),
              value: option.$1,
              groupValue: _selected,
              title: Text(option.$2),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selected = value);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancelButton),
        ),
        TextButton(
          key: const Key('settingsGenderSave'),
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(widget.l10n.saveButton),
        ),
      ],
    );
  }
}
