import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../models/ai_task_draft.dart';
import '../services/ai_chat_service.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'expandable_bottom_sheet.dart';
import 'tasks_glass.dart';

Future<AiTaskDraft?> showTaskAiAssistSheet(BuildContext context) {
  final palette = context.read<TasksViewModel>().palette;
  final themeData = context.read<TasksViewModel>().themeData;
  return showExpandableModalBottomSheet<AiTaskDraft>(
    context: context,
    initialChildSize: 0.55,
    minChildSize: 0.4,
    maxChildSize: ExpandableSheetDefaults.maxChildSize,
    builder: (sheetContext, scrollController) => Theme(
      data: themeData,
      child: TaskAiAssistSheet(
        palette: palette,
        scrollController: scrollController,
      ),
    ),
  );
}

class TaskAiAssistSheet extends StatefulWidget {
  const TaskAiAssistSheet({
    super.key,
    required this.palette,
    required this.scrollController,
  });

  final TasksUiPalette palette;
  final ScrollController scrollController;

  @override
  State<TaskAiAssistSheet> createState() => _TaskAiAssistSheetState();
}

class _TaskAiAssistSheetState extends State<TaskAiAssistSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _speech = SpeechToText();

  bool _isListening = false;
  bool _isProcessing = false;
  bool? _speechAvailable;
  String? _error;

  TasksUiPalette get palette => widget.palette;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechAvailable != null) return _speechAvailable!;
    _speechAvailable = await _speech.initialize(
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _error = TaskStrings.of(context).taskAiMicUnavailable;
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    return _speechAvailable!;
  }

  Future<void> _toggleMic() async {
    final strings = TaskStrings.of(context);
    setState(() => _error = null);

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _ensureSpeechReady();
    if (!mounted) return;
    if (!available) {
      setState(() => _error = strings.taskAiMicUnavailable);
      return;
    }

    final preferred = Localizations.localeOf(context);
    final locales = await _speech.locales();
    if (!mounted) return;
    final localeId = _resolveSpeechLocaleId(locales, preferred);

    setState(() => _isListening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
        localeId: localeId,
      ),
      onResult: (result) {
        if (!mounted) return;
        // Update text without rebuilding the glass sheet on every partial.
        final words = result.recognizedWords;
        _controller.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
      },
    );
  }

  String _resolveSpeechLocaleId(List<LocaleName> locales, Locale preferred) {
    String? find(bool Function(String normalizedId) test) {
      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (test(normalized)) return locale.localeId;
      }
      return null;
    }

    final lang = preferred.languageCode.toLowerCase();
    final country = (preferred.countryCode ?? (lang == 'uk' ? 'ua' : ''))
        .toLowerCase();

    if (country.isNotEmpty) {
      final exact = find((id) => id == '${lang}_$country');
      if (exact != null) return exact;
    }

    final byLang = find((id) => id == lang || id.startsWith('${lang}_'));
    if (byLang != null) return byLang;

    final uk = find((id) => id == 'uk' || id.startsWith('uk_'));
    if (uk != null) return uk;

    return lang == 'uk' ? 'uk_UA' : 'en_US';
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing) {
      if (text.isEmpty) {
        setState(() => _error = TaskStrings.of(context).taskAiEmptyPrompt);
        _focus.requestFocus();
      }
      return;
    }

    final ai = context.read<AiChatService>();

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final draft = await ai.parseTaskDraft(text);
      if (!mounted) return;
      Navigator.of(context).pop(draft);
    } catch (e) {
      if (!mounted) return;
      final fallback = TaskStrings.of(context).taskAiProcessError;
      setState(() {
        _isProcessing = false;
        _error = e.toString().trim().isEmpty ? fallback : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);

    return TasksGlassSheet(
      palette: palette,
      blur: 14,
      fillHeight: true,
      child: SafeArea(
        top: false,
        child: ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            BottomSheetDragHandle(
              color: palette.textMuted.withValues(alpha: 0.3),
              width: 40,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_awesome, color: palette.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.taskAiAssistTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.taskAiAssistHint,
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
            const SizedBox(height: 16),
            TasksGlassPanel(
              palette: palette,
              blur: 0,
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 5,
                      enabled: !_isProcessing,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      enableSuggestions: true,
                      enableIMEPersonalizedLearning: true,
                      style: TextStyle(
                        fontSize: 15,
                        color: palette.textPrimary,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: strings.taskAiPromptHint,
                        hintStyle: TextStyle(color: palette.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  _RoundAction(
                    palette: palette,
                    icon: _isListening ? Icons.mic : Icons.mic_none,
                    active: _isListening,
                    onPressed: _isProcessing ? null : _toggleMic,
                    tooltip: strings.taskAiMicTooltip,
                  ),
                  const SizedBox(width: 6),
                  _RoundAction(
                    palette: palette,
                    icon: Icons.arrow_upward_rounded,
                    primary: true,
                    busy: _isProcessing,
                    onPressed: _isProcessing ? null : _submit,
                    tooltip: strings.taskAiSendTooltip,
                  ),
                ],
              ),
            ),
            if (_isListening) ...[
              const SizedBox(height: 10),
              Text(
                strings.taskAiListening,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.primary,
                ),
              ),
            ],
            if (_isProcessing) ...[
              const SizedBox(height: 10),
              Text(
                strings.taskAiProcessing,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.palette,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.active = false,
    this.primary = false,
    this.busy = false,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: TasksGlassPanel(
          palette: palette,
          borderRadius: BorderRadius.circular(22),
          blur: 0,
          tint: primary
              ? palette.primary.withValues(alpha: palette.isDark ? 0.88 : 0.92)
              : active
              ? palette.primary.withValues(alpha: 0.35)
              : palette.glassChipFill,
          child: SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.onPrimary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 22,
                    color: primary
                        ? palette.onPrimary
                        : active
                        ? palette.primary
                        : palette.textPrimary,
                  ),
          ),
        ),
      ),
    );

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
