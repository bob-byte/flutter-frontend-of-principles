import 'package:flutter/material.dart';

import '../l10n/task_strings.dart';
import 'theme_color_picker.dart';

enum ThemePickerMode { none, existing, newTheme }

class ThemePickerSection extends StatelessWidget {
  const ThemePickerSection({
    super.key,
    required this.mode,
    required this.colorForTheme,
    required this.existingThemes,
    required this.selectedTheme,
    required this.selectedColor,
    required this.newThemeName,
    required this.onModeChanged,
    required this.onThemeSelected,
    required this.onNewThemeNameChanged,
    required this.onColorSelected,
    required this.strings,
  });

  final ThemePickerMode mode;
  final Color Function(String theme) colorForTheme;
  final List<String> existingThemes;
  final String? selectedTheme;
  final Color selectedColor;
  final String newThemeName;
  final ValueChanged<ThemePickerMode> onModeChanged;
  final ValueChanged<String?> onThemeSelected;
  final ValueChanged<String> onNewThemeNameChanged;
  final ValueChanged<Color> onColorSelected;
  final TaskStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.taskThemeOptional,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModeChip(
              label: strings.taskNoTheme,
              selected: mode == ThemePickerMode.none,
              onTap: () {
                onModeChanged(ThemePickerMode.none);
                onThemeSelected(null);
              },
            ),
            _ModeChip(
              label: strings.taskNewTheme,
              selected: mode == ThemePickerMode.newTheme,
              onTap: () => onModeChanged(ThemePickerMode.newTheme),
            ),
          ],
        ),
        if (existingThemes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: existingThemes.map((theme) {
              final selected =
                  mode == ThemePickerMode.existing && selectedTheme == theme;
              final color = colorForTheme(theme);
              return GestureDetector(
                onTap: () {
                  onModeChanged(ThemePickerMode.existing);
                  onThemeSelected(theme);
                  onColorSelected(color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? color : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? color
                          : scheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        theme,
                        style: TextStyle(
                          color: selected ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (mode == ThemePickerMode.newTheme) ...[
          const SizedBox(height: 12),
          _NewThemeNameField(
            value: newThemeName,
            hint: strings.taskNewTheme,
            onChanged: onNewThemeNameChanged,
          ),
          const SizedBox(height: 12),
          ThemeColorPicker(
            label: strings.taskThemeColor,
            selected: selectedColor,
            onSelected: onColorSelected,
          ),
        ],
      ],
    );
  }
}

class _NewThemeNameField extends StatefulWidget {
  const _NewThemeNameField({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_NewThemeNameField> createState() => _NewThemeNameFieldState();
}

class _NewThemeNameFieldState extends State<_NewThemeNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_NewThemeNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(hintText: widget.hint),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : Border.all(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
