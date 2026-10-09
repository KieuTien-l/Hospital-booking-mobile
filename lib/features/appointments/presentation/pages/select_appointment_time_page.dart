import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/presentation/controllers/schedule_controller.dart';
import '../../../doctors/presentation/models/doctor_detail_demo_data.dart';
import '../../../doctors/presentation/pages/doctor_detail_page.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_time_ui_models.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../models/appointment_confirmation_demo_data.dart';
import 'appointment_information_page.dart';
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

  /// When omitted, doctors and five days of availability load from Firebase.
  /// An explicit list is useful for previews and widget tests.
  final List<AppointmentDoctorOption>? doctors;
  final ValueChanged<AppointmentTimeSelection>? onContinue;

  @override
  State<SelectAppointmentTimePage> createState() =>
      _SelectAppointmentTimePageState();
}

class _SelectAppointmentTimePageState extends State<SelectAppointmentTimePage> {
  late DateTime _date;
  List<AppointmentDoctorOption> _doctors = [];
  final Set<String> _expanded = {};
  AppointmentTimeSelection? _selection;
  bool _loading = false;
  String? _error;
  int _loadRequest = 0;
  final Map<String, Doctor> _loadedDoctors = {};

  @override
  void initState() {
    super.initState();
    _reset();
    _loadData();
  }

  void _reset() {
    _date = DateUtils.dateOnly(widget.initialDate);
    _doctors = widget.doctors ?? [];
    _loadedDoctors.clear();
    _selection = null;
    _expanded.clear();
    if (_doctors.isNotEmpty) _expanded.add(_doctors.first.id);
  }

  Future<void> _loadData({bool clearSelection = false}) async {
    if (widget.doctors != null) return;
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
      if (clearSelection) _selection = null;
    });
    try {
      final docRepo = context.read<DoctorRepository>();
      final schedCtrl = context.read<ScheduleController>();

      final realDoctors = await docRepo.getDoctorsBySpecialty(
        widget.specialty.id,
      );
      final schedules = await schedCtrl.loadWeeklySchedulesForDoctors(
        doctors: realDoctors,
        startDate: _date,
        days: 5,
      );
      if (!mounted || request != _loadRequest) return;

      final dates = List<DateTime>.generate(
        5,
        (index) => _date.add(Duration(days: index)),
        growable: false,
      );
      final mappedDoctors = <AppointmentDoctorOption>[];
      for (final doctor in realDoctors) {
        final docSchedules = schedules[doctor.id] ?? {};
        final mappedSchedule = <DateTime, List<AppointmentTimeOption>>{
          for (final day in dates)
            day: [
              for (final slot in docSchedules[day] ?? const [])
                AppointmentTimeOption(
                  id: slot.id,
                  workScheduleId: slot.workScheduleId,
                  label: '${slot.startTime ?? ''} - ${slot.endTime ?? ''}',
                  startTime: slot.startTime,
                  endTime: slot.endTime,
                  available: slot.isAvailable,
                ),
            ],
        };
        final qualification = doctor.qualification?.trim() ?? '';
        final name = doctor.fullName.trim();
        final fullName = qualification.isEmpty ? name : '$qualification. $name';
        mappedDoctors.add(
          AppointmentDoctorOption(
            id: doctor.id,
            name: fullName,
            location: doctor.specialtyName ?? widget.specialty.name,
            session: 'Lịch trống',
            avatarUrl: doctor.avatarUrl,
            schedule: mappedSchedule,
          ),
        );
      }
      setState(() {
        _loadedDoctors
          ..clear()
          ..addEntries(
            realDoctors.map((doctor) => MapEntry(doctor.id, doctor)),
          );
        _doctors = mappedDoctors;
        _expanded.clear();
        if (_doctors.isNotEmpty) _expanded.add(_doctors.first.id);
        _loading = false;
      });
    } catch (e) {
      if (mounted && request == _loadRequest) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _continueBooking() async {
    final selection = _selection;
    if (selection == null) return;
    if (widget.onContinue != null) {
      widget.onContinue!(selection);
      return;
    }

    final doctor = _loadedDoctors[selection.doctor.id];
    if (doctor == null) {
      _openPreviewConfirmation(selection);
      return;
    }

    final routePatient = ModalRoute.of(context)?.settings.arguments;
    final patient = routePatient is Patient
        ? routePatient
        : context.read<PatientProfileController?>()?.patient;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConfirmAppointmentPage(
          information: AppointmentConfirmationUiModel(
            specialtyName: widget.specialty.name,
            selection: selection,
            patientName: patient?.fullName,
            patient: patient,
            fee: doctor.consultationFee.toInt(),
          ),
          onSubmitBooking: (_) => _submitLiveBooking(
            doctor: doctor,
            selection: selection,
            patient: patient,
          ),
        ),
      ),
    );
  }

  Future<String?> _submitLiveBooking({
    required Doctor doctor,
    required AppointmentTimeSelection selection,
    required Patient? patient,
  }) async {
    if (patient == null) {
      return 'Vui lòng cập nhật hồ sơ bệnh nhân trước.';
    }
    final controller = context.read<AppointmentController>();
    final result = await controller.book(
      patientId: patient.id,
      doctorId: doctor.id,
      workScheduleId: selection.slot.workScheduleId,
      timeSlotId: selection.slot.id,
      appointmentDate: selection.date,
      startTime: selection.slot.startTime,
      endTime: selection.slot.endTime,
    );
    if (result != null) return null;

    final message =
        controller.errorMessage ?? 'Không thể đặt lịch. Vui lòng thử lại.';
    await _loadData(clearSelection: true);
    return message;
  }

  void _openPreviewConfirmation(AppointmentTimeSelection selection) {
    final profile = ModalRoute.of(context)?.settings.arguments;
    final fee = AppointmentConfirmationDemoData.feeForDoctor(
      selection.doctor.id,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConfirmAppointmentPage(
          information: AppointmentConfirmationUiModel(
            specialtyName: widget.specialty.name,
            selection: selection,
            patientName: profile is Patient ? profile.fullName : null,
            patient: profile is Patient ? profile : null,
            fee: fee,
            isDemoFee: fee != null,
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SelectAppointmentTimePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctors != widget.doctors ||
        oldWidget.initialDate != widget.initialDate ||
        oldWidget.specialty.id != widget.specialty.id) {
      _loadRequest++;
      _reset();
      _loadData();
    }
  }

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
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: AppLoadingWidget(
                        message: 'Đang tải lịch trống của bác sĩ...',
                      ),
                    )
                  else if (_error != null)
                    AppErrorWidget(message: _error!, onRetry: _loadData)
                  else if (_doctors.isEmpty)
                    const AppEmptyWidget(
                      message: 'Chưa có bác sĩ và lịch khám để hiển thị.',
                    )
                  else
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
                    onPressed: _loading || _selection == null
                        ? null
                        : _continueBooking,
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
