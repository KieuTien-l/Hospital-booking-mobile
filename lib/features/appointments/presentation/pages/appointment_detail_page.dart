import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../profile/presentation/widgets/health_records_date_filter.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_history_ui_model.dart';
import 'reschedule_appointment_page.dart';

/// Live appointment detail and patient actions for KieuTien's history UI.
class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({super.key, required this.item});

  final AppointmentHistoryUiModel item;

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  bool _working = false;

  Appointment get _appointment => widget.item.appointment;

  bool get _canManage =>
      _appointment.status == AppointmentStatus.pending ||
      _appointment.status == AppointmentStatus.confirmed;

  Future<void> _cancelAppointment() async {
    final reason = await _askForCancellationReason();
    if (reason == null || !mounted) return;

    setState(() => _working = true);
    final updated = await context
        .read<AppointmentController>()
        .cancelAppointment(_appointment.id, reason);
    if (!mounted) return;
    setState(() => _working = false);
    if (updated == null) {
      _showMessage(
        context.read<AppointmentController>().errorMessage ??
            'Không thể hủy lịch hẹn. Vui lòng thử lại.',
      );
      return;
    }
    _showMessage('Đã hủy lịch hẹn và giải phóng khung giờ.');
    Navigator.of(context).pop(true);
  }

  Future<void> _rescheduleAppointment() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RescheduleAppointmentPage(appointment: _appointment),
      ),
    );
    if (!mounted || changed != true) return;
    Navigator.of(context).pop(true);
  }

  Future<String?> _askForCancellationReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận hủy lịch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Lý do hủy (bắt buộc)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: Scaffold(
      backgroundColor: AppColors.primarySoft,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Chi tiết lịch hẹn'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Thông tin lịch hẹn', [
              ('Mã lịch hẹn', _appointment.id),
              ('Bệnh nhân', widget.item.patientName),
              ('Chuyên khoa', widget.item.specialtyName),
              ('Bác sĩ', widget.item.doctorName),
              (
                'Ngày khám',
                _appointment.appointmentDate == null
                    ? 'Chưa cập nhật'
                    : HealthRecordsDateFilter.format(
                        _appointment.appointmentDate!,
                      ),
              ),
              (
                'Khung giờ',
                '${_appointment.startTime ?? '--:--'} – '
                    '${_appointment.endTime ?? '--:--'}',
              ),
              ('Trạng thái', _statusLabel(_appointment.status)),
              if (widget.item.room?.isNotEmpty ?? false)
                ('Phòng khám', widget.item.room!),
            ]),
            if (_appointment.reason?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _textSection('Lý do khám', _appointment.reason!),
            ],
            if (_appointment.symptoms?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _textSection('Triệu chứng', _appointment.symptoms!),
            ],
            if (_appointment.cancellationReason?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _textSection('Lý do hủy', _appointment.cancellationReason!),
            ],
            if (_canManage) ...[
              const SizedBox(height: 28),
              OutlinedButton.icon(
                key: const ValueKey('reschedule-appointment'),
                onPressed: _working ? null : _rescheduleAppointment,
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Thay đổi lịch'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('cancel-appointment'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: _working ? null : _cancelAppointment,
                icon: _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Hủy lịch'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _section(String title, List<(String, String)> rows) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
        ),
        const SizedBox(height: 14),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    row.$1,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _textSection(String title, String value) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(height: 1.5)),
      ],
    ),
  );

  String _statusLabel(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => 'Chờ xác nhận',
    AppointmentStatus.confirmed => 'Đã xác nhận',
    AppointmentStatus.completed => 'Đã hoàn thành',
    AppointmentStatus.cancelled => 'Đã hủy',
    AppointmentStatus.noShow => 'Vắng mặt',
    AppointmentStatus.unknown => 'Chưa xác định',
  };
}
