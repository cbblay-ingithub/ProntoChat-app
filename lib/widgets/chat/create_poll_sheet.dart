import 'package:flutter/material.dart';
import '../../models/poll_model.dart';

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
        validOptions.add(PollOption(
          id: 'opt_${i + 1}',
          text: text,
        ));
      }
    }

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options.')),
      );
      return;
    }

    final now = DateTime.now();
    final closesAt = _selectedDuration != null ? now.add(_selectedDuration!) : null;

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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(28, 27, 28, 1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.poll_rounded, color: widget.primaryColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Create Poll',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Field
              const Text(
                'Question',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _questionController,
                maxLength: 200,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromRGBO(40, 39, 42, 1),
                  counterStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Options Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Options (2 to 6)',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (_optionControllers.length < 6)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: Icon(Icons.add, size: 16, color: widget.primaryColor),
                      label: Text('Add Option', style: TextStyle(color: widget.primaryColor, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Option Input Fields
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          maxLength: 80,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Option ${index + 1}',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color.fromRGBO(40, 39, 42, 1),
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeOption(index),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Settings Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow multiple answers', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Members can vote for more than one option', style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: _allowMultiple,
                activeColor: widget.primaryColor,
                onChanged: (val) => setState(() => _allowMultiple = val),
              ),
              const SizedBox(height: 8),

              // Duration Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Poll closes in', style: TextStyle(color: Colors.white, fontSize: 14)),
                  DropdownButton<Duration?>(
                    value: _selectedDuration,
                    dropdownColor: const Color.fromRGBO(40, 39, 42, 1),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
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

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Poll', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
