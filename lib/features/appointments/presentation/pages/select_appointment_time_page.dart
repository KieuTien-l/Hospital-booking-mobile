import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../doctors/presentation/models/doctor_detail_demo_data.dart';
import '../../../doctors/presentation/pages/doctor_detail_page.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../models/appointment_time_demo_data.dart';
import '../models/appointment_time_ui_models.dart';
import '../widgets/appointment_doctor_card.dart';

class SelectAppointmentTimePage extends StatefulWidget {
  const SelectAppointmentTimePage({
    super.key,
    required this.specialty,
    required this.initialDate,
    this.doctors,
    this.onContinue,
  });
  final Specialty specialty;
  final DateTime initialDate;

  /// Null uses local demo fixtures; an empty list stays empty.
  final List<AppointmentDoctorOption>? doctors;
  final ValueChanged<AppointmentTimeSelection>? onContinue;

  @override
  State<SelectAppointmentTimePage> createState() =>
      _SelectAppointmentTimePageState();
}

class _SelectAppointmentTimePageState extends State<SelectAppointmentTimePage> {
  late DateTime _date;
  late List<AppointmentDoctorOption> _doctors;
  final Set<String> _expanded = {};
  AppointmentTimeSelection? _selection;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _date = DateUtils.dateOnly(widget.initialDate);
    _doctors = widget.doctors ?? AppointmentTimeDemoData.doctors(_date);
    _selection = null;
    _expanded.clear();
    if (_doctors.isNotEmpty) _expanded.add(_doctors.first.id);
  }

  @override
  void didUpdateWidget(covariant SelectAppointmentTimePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctors != widget.doctors ||
        oldWidget.initialDate != widget.initialDate ||
        oldWidget.specialty.id != widget.specialty.id) {
      _reset();
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: PatientHomeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: AppColors.textOnPrimary),
          title: const Text(
            'Chọn khung giờ khám',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'CHỌN KHUNG GIỜ KHÁM',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Vui lòng chọn khung giờ còn trống để đặt khám.'),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.specialty.name} • Ngày khám: ${appointmentDateLabel(_date)}',
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_doctors.isEmpty)
                    const Text('Chưa có bác sĩ và lịch khám để hiển thị.'),
                  for (final doctor in _doctors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AppointmentDoctorCard(
                        doctor: doctor,
                        expanded: _expanded.contains(doctor.id),
                        date: _date,
                        selectedSlotId: _selection?.doctor.id == doctor.id
                            ? _selection?.slot.id
                            : null,
                        onToggle: () => setState(() {
                          if (!_expanded.remove(doctor.id)) {
                            _expanded.add(doctor.id);
                          }
                        }),
                        onInfo: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailPage(
                              doctor: DoctorDetailDemoData.forDoctor(
                                id: doctor.id,
                                name: doctor.name,
                                specialty: widget.specialty.name,
                                avatarUrl: doctor.avatarUrl,
                                location: doctor.location,
                                session: doctor.session,
                              ),
                            ),
                          ),
                        ),
                        onDateSelected: (date) {
                          if (!DateUtils.isSameDay(date, _date)) {
                            setState(() {
                              _date = DateUtils.dateOnly(date);
                              _selection = null;
                            });
                          }
                        },
                        onSlotSelected: (slot) {
                          if (slot.available) {
                            setState(
                              () => _selection = AppointmentTimeSelection(
                                doctor: doctor,
                                date: _date,
                                slot: slot,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (_selection != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'Đã chọn: ${_selection!.doctor.name}\n${appointmentDateLabel(_selection!.date)} • ${_selection!.slot.label}',
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    key: const ValueKey('continue-time'),
                    onPressed: _selection == null
                        ? null
                        : () {
                            if (widget.onContinue != null) {
                              widget.onContinue!(_selection!);
                            } else {
                              _message(
                                'Đã chọn khung giờ. Bước xác nhận đặt khám đang được hoàn thiện.',
                              );
                            }
                          },
                    child: const Text('TIẾP TỤC'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
