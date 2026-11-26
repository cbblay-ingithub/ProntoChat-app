import 'package:flutter/material.dart';
import '../../models/poll_model.dart';
import '../../theme/pc_tokens.dart';

class CreatePollSheet extends StatefulWidget {
  final Color primaryColor;
  final String currentUid;
  final ValueChanged<PollModel> onPollCreated;

  const CreatePollSheet({
    super.key,
    required this.primaryColor,
    required this.currentUid,
    required this.onPollCreated,
  });

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultiple = false;
  Duration? _selectedDuration;

  final List<Duration?> _durationOptions = [
    null,
    const Duration(hours: 1),
    const Duration(hours: 24),
    const Duration(days: 3),
    const Duration(days: 7),
  ];

  String _durationLabel(Duration? d) {
    if (d == null) return 'No limit';
    if (d.inHours == 1) return '1 Hour';
    if (d.inHours == 24) return '24 Hours (1 Day)';
    if (d.inDays == 3) return '3 Days';
    if (d.inDays == 7) return '7 Days';
    return '${d.inDays} Days';
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        final controller = _optionControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question.')),
      );
      return;
    }

    final validOptions = <PollOption>[];
    for (var i = 0; i < _optionControllers.length; i++) {
      final text = _optionControllers[i].text.trim();
      if (text.isNotEmpty) {
        validOptions.add(
          PollOption(
            id: 'opt_${i + 1}',
            text: text,
          ),
        );
      }
    }

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options.')),
      );
      return;
    }

    final now = DateTime.now();
    final closesAt =
        _selectedDuration != null ? now.add(_selectedDuration!) : null;

    final poll = PollModel(
      question: question,
      options: validOptions,
      optionIds: validOptions.map((o) => o.id).toList(),
      allowMultiple: _allowMultiple,
      closesAt: closesAt,
      createdBy: widget.currentUid,
    );

    widget.onPollCreated(poll);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.poll_rounded,
                        color: widget.primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create Poll',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Question',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _questionController,
                maxLength: 200,
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceSubtle,
                  counterStyle: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Options (2 to 6)',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_optionControllers.length < 6)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: widget.primaryColor,
                      ),
                      label: Text(
                        'Add Option',
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          maxLength: 80,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Option ${index + 1}',
                            hintStyle: TextStyle(color: tokens.textMuted),
                            filled: true,
                            fillColor: tokens.surfaceSubtle,
                            counterText: '',
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            color: tokens.urgentText,
                            size: 20,
                          ),
                          onPressed: () => _removeOption(index),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Allow multiple answers',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'Members can vote for more than one option',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                value: _allowMultiple,
                activeThumbColor: widget.primaryColor,
                onChanged: (val) => setState(() => _allowMultiple = val),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Poll closes in',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                  ),
                  DropdownButton<Duration?>(
                    value: _selectedDuration,
                    dropdownColor: tokens.surface,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: _durationOptions.map((d) {
                      return DropdownMenuItem<Duration?>(
                        value: d,
                        child: Text(_durationLabel(d)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDuration = val),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create Poll',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
