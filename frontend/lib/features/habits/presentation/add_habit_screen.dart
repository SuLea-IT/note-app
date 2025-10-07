import '../../../core/localization/locale_utils.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/habit_controller.dart';
import '../domain/entities/habit_entry.dart';
import '../domain/entities/habit_status.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeLabelController = TextEditingController();

  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  String _repeatRule = 'daily';
  late Color _selectedColor;

  final _colorPalette = [
    AppColors.accentPurple,
    AppColors.accentGreen,
    AppColors.accentYellow,
    AppColors.accentPink,
    Color(0xFF4CAF50),
    Color(0xFF7C4DFF),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = _colorPalette.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('新建习惯')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '习惯名称',
                    hintText: '例如：晨间写作',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写习惯名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: '描述',
                    hintText: '如何执行、持续时长等',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写习惯描述';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _timeLabelController,
                  decoration: InputDecoration(
                    labelText: '时间段标签',
                    hintText: '如 07:30 / 午休 / 晚间',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请填写时间标签';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(context.tr('提醒设置'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('开启提醒')),
                  subtitle: Text(context.tr('开启后将在指定时间推送通知')),
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() {
                      _reminderEnabled = value;
                      if (value && _reminderTime == null) {
                        _reminderTime = const TimeOfDay(hour: 7, minute: 30);
                      }
                    });
                  },
                ),
                if (_reminderEnabled)
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _pickReminder,
                        icon: const Icon(Icons.alarm),
                        label: Text(_reminderTime == null
                            ? '选择时间'
                            : _formatTime(_reminderTime!)),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(context.tr('重复频率'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _repeatRule,
                  items: [
                    DropdownMenuItem(value: 'daily', child: Text(context.tr('每天'))),
                    DropdownMenuItem(value: 'weekdays', child: Text(context.tr('工作日'))),
                    DropdownMenuItem(value: 'weekends', child: Text(context.tr('周末'))),
                    DropdownMenuItem(value: 'custom', child: Text(context.tr('自定义/不定期'))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _repeatRule = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(context.tr('主题颜色'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final color in _colorPalette)
                      GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  _selectedColor == color ? color : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(backgroundColor: color, radius: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(context.tr('保存习惯')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminder() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 7, minute: 30),
    );
    if (result != null) {
      setState(() => _reminderTime = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final entry = HabitEntry(
      id: '',
      title: _titleController.text.trim(),
      timeLabel: _timeLabelController.text.trim(),
      description: _descriptionController.text.trim(),
      status: HabitStatus.upcoming,
      accentColor: _selectedColor,
      reminderTime: _reminderEnabled ? _reminderTime : null,
      repeatRule: _repeatRule == 'custom' ? null : _repeatRule,
    );

    await context.read<HabitController>().addHabit(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
