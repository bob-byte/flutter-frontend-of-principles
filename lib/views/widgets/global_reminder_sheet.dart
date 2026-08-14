import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class GlobalReminderBottomSheet extends StatefulWidget {
  const GlobalReminderBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const GlobalReminderBottomSheet(),
      ),
    );
  }

  @override
  State<GlobalReminderBottomSheet> createState() => _GlobalReminderBottomSheetState();
}

class _GlobalReminderBottomSheetState extends State<GlobalReminderBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TimeOfDay _time;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    // Початкові значення за замовчуванням (як на макеті)
    _titleController = TextEditingController(text: 'Нагадайте сьогоднішні звички');
    _descController = TextEditingController(text: 'Mykola, час відзначити, які звички було виконано вчора, і нагадати про свої');
    _time = const TimeOfDay(hour: 7, minute: 0);
    _isEnabled = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              // Кнопка Готово
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              // Барабан часу
              Expanded(
                child: SafeArea(
                  top: false,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(0, 0, 0, _time.hour, _time.minute),
                    onDateTimeChanged: (DateTime newTime) {
                      setState(() {
                        _time = TimeOfDay(hour: newTime.hour, minute: newTime.minute);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() {
    // TODO: Implement global reminder logic
    // We would use ReminderService to schedule a daily local notification
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Нагадування',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Заголовок',
              prefixIcon: const Icon(Icons.local_offer_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Опис',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 40), // Align icon to top
                child: Icon(Icons.description_outlined),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: _selectTime,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Час',
                prefixIcon: const Icon(Icons.access_time),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_time.format(context), style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Switch(
                value: _isEnabled,
                onChanged: (val) => setState(() => _isEnabled = val),
                activeColor: Colors.blue,
              ),
              const Text('Увімкнути', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.cancel, size: 18),
                       SizedBox(width: 4),
                       Text('Скасувати', style: TextStyle(fontWeight: FontWeight.bold)),
                     ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _save,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18),
                      SizedBox(width: 4),
                      Text('Зберегти', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
