import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../controllers/appointment_controller.dart';

class BookingConfirmPage extends StatefulWidget {
  const BookingConfirmPage({
    super.key,
    required this.doctor,
    required this.date,
    required this.timeSlot,
    required this.workSchedule,
  });

  final Doctor doctor;
  final DateTime date;
  final TimeSlot timeSlot;
  final WorkSchedule workSchedule;

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage> {
  final _reasonController = TextEditingController();
  final _symptomsController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do khám bệnh.')),
      );
      return;
    }

    final patient = context.read<PatientProfileController?>()?.patient;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng cập nhật hồ sơ bệnh nhân trước.')),
      );
      return;
    }

    final appointmentController = context.read<AppointmentController>();
    final result = await appointmentController.book(
      patientId: patient.id,
      doctorId: widget.doctor.id,
      workScheduleId: widget.workSchedule.id,
      timeSlotId: widget.timeSlot.id,
      appointmentDate: widget.date,
      startTime: widget.timeSlot.startTime,
      endTime: widget.timeSlot.endTime,
      reason: _reasonController.text.trim(),
      symptoms: _symptomsController.text.trim(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt lịch thành công!')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác nhận đặt lịch'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<AppointmentController>(
        builder: (context, controller, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                'Thông tin lịch hẹn',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow('Bác sĩ', widget.doctor.fullName),
                    _buildRow('Chuyên khoa', widget.doctor.specialtyName ?? ''),
                    _buildRow('Ngày khám', DateFormat('dd/MM/yyyy').format(widget.date)),
                    _buildRow('Giờ khám', '${widget.timeSlot.startTime} - ${widget.timeSlot.endTime}'),
                    _buildRow('Phí khám', '${widget.doctor.consultationFee.toInt()} đ'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                'Lý do khám',
                Column(
                  children: [
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Lý do khám bệnh (bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _symptomsController,
                      decoration: const InputDecoration(
                        labelText: 'Triệu chứng chi tiết (không bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (controller.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Lỗi: ${controller.errorMessage}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ElevatedButton(
                onPressed: controller.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: controller.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Xác nhận đặt lịch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
