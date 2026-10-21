import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/admin_commands.dart';

enum AdminInput { text, multiline, email, number, integer, date, time, choice }

class AdminEditField {
  const AdminEditField(
    this.key,
    this.label, {
    this.input = AdminInput.text,
    this.required = false,
    this.initial = '',
    this.options = const {},
    this.pastDate = false,
  });
  final String key;
  final String label;
  final AdminInput input;
  final bool required;
  final String initial;
  final Map<String, String> options;
  final bool pastDate;
}

class AdminEditor extends StatefulWidget {
  const AdminEditor({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    required this.onSubmit,
    this.submitLabel = 'Lưu',
    this.initialReason = '',
  });
  final String title;
  final String description;
  final List<AdminEditField> fields;
  final String submitLabel;
  final String initialReason;
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic> values,
    String reason,
    String requestId,
  )
  onSubmit;
  @override
  State<AdminEditor> createState() => _AdminEditorState();
}

class _AdminEditorState extends State<AdminEditor> {
  final _form = GlobalKey<FormState>();
  late final _values = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initial),
  };
  late final _reason = TextEditingController(text: widget.initialReason);
  bool _busy = false;
  String? _error;
  String? _lastBody;
  String _requestId = adminRequestId();

  @override
  void dispose() {
    for (final value in _values.values) {
      value.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final values = <String, dynamic>{};
    for (final field in widget.fields) {
      final value = _values[field.key]!.text.trim();
      values[field.key] = switch (field.input) {
        AdminInput.number => double.tryParse(value),
        AdminInput.integer =>
          int.tryParse(value) ?? double.tryParse(value)?.toInt(),
        _ => value,
      };
    }
    final reason = _reason.text.trim();
    final body = jsonEncode([values, reason]);
    if (_lastBody != null && _lastBody != body) _requestId = adminRequestId();
    _lastBody = body;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(values, reason, _requestId);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AdminCommandException
              ? error.message
              : 'Không thể lưu. Vui lòng kiểm tra dữ liệu và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(AdminEditField field) async {
    if (_busy) return;
    final controller = _values[field.key]!;
    if (field.input == AdminInput.date) {
      final now = DateTime.now();
      final current = DateTime.tryParse(controller.text) ?? now;
      final value = await showDatePicker(
        context: context,
        useRootNavigator: false,
        initialDate: current.isBefore(DateTime(1900))
            ? DateTime(1900)
            : current.isAfter(field.pastDate ? now : DateTime(2100))
            ? (field.pastDate ? now : DateTime(2100))
            : current,
        firstDate: DateTime(1900),
        lastDate: field.pastDate ? now : DateTime(2100),
      );
      if (value != null) {
        controller.text =
            '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      }
    } else {
      final parts = controller.text.split(':');
      final value = await showTimePicker(
        context: context,
        useRootNavigator: false,
        initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 8,
          minute: parts.length == 2 ? int.tryParse(parts.last) ?? 0 : 0,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (value != null) {
        controller.text =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  Widget _field(AdminEditField field) {
    final controller = _values[field.key]!;
    String? validate(String? value) {
      final input = value?.trim() ?? '';
      if (field.required && input.isEmpty) {
        return 'Vui lòng nhập ${field.label.toLowerCase()}.';
      }
      if (input.isEmpty) return null;
      if (field.input == AdminInput.email &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) {
        return 'Email không hợp lệ.';
      }
      if ([AdminInput.number, AdminInput.integer].contains(field.input)) {
        final number = double.tryParse(input);
        if (number == null ||
            !number.isFinite ||
            number < 0 ||
            (field.input == AdminInput.integer &&
                number != number.roundToDouble())) {
          return 'Nhập số không âm hợp lệ.';
        }
      }
      return null;
    }

    if (field.input == AdminInput.choice) {
      final options = {...field.options};
      if (controller.text.isNotEmpty && !options.containsKey(controller.text)) {
        options[controller.text] = '${controller.text} (giá trị hiện tại)';
      }
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _busy ? null : (v) => controller.text = v ?? '',
        validator: validate,
      );
    }
    final picker = [AdminInput.date, AdminInput.time].contains(field.input);
    return TextFormField(
      controller: controller,
      enabled: !_busy,
      readOnly: picker,
      maxLength: field.input == AdminInput.multiline ? 4000 : 2048,
      maxLines: field.input == AdminInput.multiline ? 3 : 1,
      keyboardType: field.input == AdminInput.email
          ? TextInputType.emailAddress
          : [AdminInput.number, AdminInput.integer].contains(field.input)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        counterText: '',
        suffixIcon: picker
            ? IconButton(
                onPressed: _busy ? null : () => _pick(field),
                icon: Icon(
                  field.input == AdminInput.date
                      ? Icons.date_range_outlined
                      : Icons.schedule,
                ),
              )
            : null,
      ),
      onTap: picker ? () => _pick(field) : null,
      validator: validate,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0864CA),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.description,
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                      const SizedBox(height: 18),
                      for (final field in widget.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _field(field),
                        ),
                      TextFormField(
                        controller: _reason,
                        enabled: !_busy,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Lý do thao tác / ghi chú quản trị',
                        ),
                        validator: (v) => v?.trim().isNotEmpty == true
                            ? null
                            : 'Vui lòng nhập lý do để lưu nhật ký.',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB74343),
                              height: 1.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Đang xử lý…' : widget.submitLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
