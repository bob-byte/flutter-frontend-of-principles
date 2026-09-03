import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/ui_theme_switcher.dart';
import 'forget_password_view.dart';
import 'startup_view.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().load();
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
            GlassAppBar(
              title: Text(l10n.settingsTitle),
              actions: const [AppThemeSwitcher()],
            ),
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
        actions: const [AppThemeSwitcher()],
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
        builder: (context, vm, child) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
          children: [
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                if (vm.isLoadingProfile ||
                    vm.isSavingProfile ||
                    vm.isDeletingAccount)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                GlassListTile(
                  key: const Key('settingsProfileNameTile'),
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
                  key: const Key('settingsProfileSloganTile'),
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(l10n.sloganLabel),
                  subtitle: Text(
                    vm.mainSlogan.isEmpty ? l10n.optionalLabel : vm.mainSlogan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: GlassListTile.chevron,
                  onTap: () => _editSlogan(context, vm, l10n),
                ),
                GlassListTile(
                  key: const Key('settingsProfileMissionTile'),
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
            const SizedBox(height: 16),
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.languageLabel),
                  subtitle: Text(l10n.languageSubtitle),
                  trailing: DropdownButton<Locale?>(
                    value: vm.localeOverride,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem<Locale?>(
                        value: null,
                        child: Text(l10n.languageSystem),
                      ),
                      DropdownMenuItem<Locale?>(
                        value: const Locale('en'),
                        child: Text(l10n.languageEnglish),
                      ),
                      DropdownMenuItem<Locale?>(
                        value: const Locale('uk'),
                        child: Text(l10n.languageUkrainian),
                      ),
                    ],
                    onChanged: (value) => vm.setLocaleOverride(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutProgram),
                  trailing: GlassListTile.chevron,
                  onTap: vm.openAboutSite,
                ),
                GlassListTile(
                  key: const Key('settingsTelegramTile'),
                  leading: const Icon(Icons.telegram),
                  title: Text(l10n.joinTelegramLabel),
                  trailing: GlassListTile.chevron,
                  onTap: vm.openTelegramChannel,
                ),
                if (!kIsWeb)
                  GlassListTile(
                    key: const Key('settingsRateUsTile'),
                    leading: const Icon(Icons.star_outline),
                    title: Text(l10n.rateUsLabel),
                    trailing: GlassListTile.chevron,
                    onTap: vm.rateApp,
                  ),
                GlassListTile(
                  key: const Key('settingsShareAppTile'),
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l10n.shareAppLabel),
                  trailing: GlassListTile.chevron,
                  onTap: () => vm.shareApp(l10n.shareAppMessage),
                ),
                GlassListTile(
                  key: const Key('settingsContactEmailTile'),
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
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.settingsPrivacyPolicy),
                  trailing: GlassListTile.chevron,
                  onTap: vm.openPrivacyPolicy,
                ),
                GlassListTile(
                  key: const Key('settingsUserAgreementTile'),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.settingsUserAgreement),
                  trailing: GlassListTile.chevron,
                  onTap: vm.openUserAgreement,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
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
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.logoutLabel),
                  onTap: () => _logout(context, vm),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassGroupedSection(
              useOwnLayer: true,
              children: [
                GlassListTile(
                  key: const Key('settingsDeleteAccountTile'),
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
        ),
      ),
    );
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.emailLabel),
        content: Text(l10n.fieldIsNotEditable),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.okButton),
          ),
        ],
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.errorTitle),
        content: Text(l10n.cannotOpenEmailApp),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.okButton),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, SettingsViewModel vm) async {
    await vm.clearProfile();
    if (!context.mounted) return;
    await context.read<AuthService>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(StartupView.routeName, (route) => false);
  }

  Future<void> _deleteAccount(
    BuildContext context,
    SettingsViewModel vm,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteAccountQuestion),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.noButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.yesButton),
          ),
        ],
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: SingleChildScrollView(
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
                        icon: const Icon(Icons.info_outline),
                        onPressed: () {
                          setState(() => _showExplanation = !_showExplanation);
                        },
                      ),
              ),
            ),
            if (_showExplanation && widget.explanation != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.explanation!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
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
