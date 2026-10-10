import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../profile/presentation/widgets/health_records_date_filter.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_history_ui_model.dart';
import 'appointment_detail_page.dart';
import '../widgets/appointment_history_card.dart';
import '../widgets/appointment_history_filter_sheet.dart';

class AppointmentHistoryPage extends StatefulWidget {
  const AppointmentHistoryPage({
    super.key,
    this.items = const [],
    this.patientId,
    this.patientName,
    this.isDemo = false,
    this.viewState = ViewState.success,
    this.errorMessage,
    this.onRetry,
    this.onAppointmentTap,
    this.initialDate,
  });

  final List<AppointmentHistoryUiModel> items;
  final String? patientId;
  final String? patientName;
  final bool isDemo;
  final ViewState viewState;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<AppointmentHistoryUiModel>? onAppointmentTap;
  final DateTime? initialDate;

  @override
  State<AppointmentHistoryPage> createState() => _AppointmentHistoryPageState();
}

class _AppointmentHistoryPageState extends State<AppointmentHistoryPage> {
  late AppointmentHistoryTab _tab;
  DateTimeRange? _range;
  String? _specialty;
  bool _filterOpen = false;
  String? _loadedPatientId;
  final Map<String, Doctor> _doctors = {};
  final Set<String> _requestedDoctorIds = {};
  List<AppointmentHistoryUiModel> _liveItems = const [];

  bool get _usesLiveData =>
      widget.items.isEmpty &&
      !widget.isDemo &&
      widget.patientId?.trim().isNotEmpty == true &&
      widget.viewState == ViewState.success;

  List<AppointmentHistoryUiModel> get _items =>
      _usesLiveData ? _liveItems : widget.items;

  List<AppointmentHistoryUiModel> get _scoped => _items
      .where(
        (item) =>
            widget.patientId == null ||
            item.appointment.patientId == widget.patientId,
      )
      .toList();

  List<AppointmentHistoryUiModel> get _visible => _scoped.where((item) {
    if (item.tab != _tab) return false;
    if (_specialty != null && item.appointment.specialtyId != _specialty) {
      return false;
    }
    if (_range != null) {
      final date = item.appointment.appointmentDate;
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(_range!.start) || day.isAfter(_range!.end)) return false;
    }
    return true;
  }).toList();

  @override
  void initState() {
    super.initState();
    _tab = _usesLiveData
        ? AppointmentHistoryTab.pending
        : AppointmentHistoryTab.paid;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadLiveAppointments(),
    );
  }

  void _loadLiveAppointments({bool force = false}) {
    final controller = context.read<AppointmentController?>();
    final patientId = widget.patientId?.trim();
    if (!_usesLiveData ||
        controller == null ||
        patientId == null ||
        patientId.isEmpty ||
        (!force && patientId == _loadedPatientId)) {
      return;
    }
    _loadedPatientId = patientId;
    controller.loadAppointments(patientId);
  }

  void _syncLiveItems(AppointmentController? controller) {
    if (!_usesLiveData || controller == null) return;
    final appointments = controller.appointments;
    _requestDoctorLabels(appointments);
    _liveItems = List.unmodifiable([
      for (final appointment in appointments) _toUiModel(appointment),
    ]);
  }

  AppointmentHistoryUiModel _toUiModel(Appointment appointment) {
    final doctor = _doctors[appointment.doctorId];
    final doctorName = doctor == null
        ? 'Bác sĩ ${appointment.doctorId}'
        : 'BS. ${doctor.fullName}';
    final specialtyName = doctor?.specialtyName?.trim().isNotEmpty == true
        ? doctor!.specialtyName!
        : appointment.specialtyId?.trim().isNotEmpty == true
        ? 'Chuyên khoa ${appointment.specialtyId}'
        : 'Chuyên khoa chưa cập nhật';
    return AppointmentHistoryUiModel(
      appointment: appointment,
      patientName: widget.patientName?.trim().isNotEmpty == true
          ? widget.patientName!.trim()
          : 'Bệnh nhân',
      specialtyName: specialtyName,
      doctorName: doctorName,
    );
  }

  void _requestDoctorLabels(Iterable<Appointment> appointments) {
    final repository = context.read<DoctorRepository?>();
    if (repository == null) return;
    final ids = appointments
        .map((appointment) => appointment.doctorId)
        .where((id) => id.trim().isNotEmpty && _requestedDoctorIds.add(id))
        .toList(growable: false);
    if (ids.isEmpty) return;
    Future.wait(ids.map(repository.getDoctorById))
        .then((values) {
          if (!mounted) return;
          var changed = false;
          for (final doctor in values) {
            if (doctor != null && _doctors[doctor.id] != doctor) {
              _doctors[doctor.id] = doctor;
              changed = true;
            }
          }
          if (changed) setState(() {});
        })
        .catchError((_) {});
  }

  Future<void> _filter() async {
    if (_filterOpen) return;
    final now =
        widget.initialDate ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(now.year, now.month, now.day);
    final specialties = <String, String>{
      for (final item in _scoped)
        if (item.appointment.specialtyId?.isNotEmpty ?? false)
          item.appointment.specialtyId!: item.specialtyName,
    };
    var lastDate = DateTime(today.year + 10, 12, 31);
    for (final item in _scoped) {
      final date = item.appointment.appointmentDate;
      if (date != null && date.isAfter(lastDate)) lastDate = date;
    }
    setState(() => _filterOpen = true);
    final result =
        await showModalBottomSheet<
          ({DateTimeRange? range, String? specialtyId})
        >(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          backgroundColor: AppColors.surface,
          builder: (_) => AppointmentHistoryFilterSheet(
            today: today,
            lastDate: lastDate,
            initialRange: _range,
            initialSpecialty: _specialty,
            specialties: specialties,
          ),
        );
    if (!mounted) return;
    setState(() {
      _filterOpen = false;
      if (result != null) {
        _range = result.range;
        _specialty = result.specialtyId;
      }
    });
  }

  Widget _message(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.background,
            child: Icon(
              Icons.description_outlined,
              size: 46,
              color: AppColors.disabled,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ],
      ),
    ),
  );

  Widget _content(
    BuildContext context, {
    required ViewState state,
    required String? errorMessage,
    VoidCallback? onRetry,
  }) {
    if (state == ViewState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state == ViewState.error) {
      return _message(
        context,
        'Không thể hiển thị lịch khám',
        errorMessage ?? 'Vui lòng thử lại sau.',
        onRetry: onRetry,
      );
    }
    final visible = state == ViewState.empty || state == ViewState.initial
        ? <AppointmentHistoryUiModel>[]
        : _visible;
    if (visible.isEmpty) {
      return _message(
        context,
        'Không có dữ liệu',
        _range != null || _specialty != null
            ? 'Không có lịch khám phù hợp với bộ lọc.'
            : 'Chưa có lịch khám nào trong trạng thái này.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: visible.length,
      separatorBuilder: (_, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => AppointmentHistoryCard(
        item: visible[index],
        onTap: () {
          if (widget.onAppointmentTap != null) {
            widget.onAppointmentTap!(visible[index]);
            return;
          }
          if (_usesLiveData) {
            Navigator.of(context)
                .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AppointmentDetailPage(item: visible[index]),
                  ),
                )
                .then((_) => _loadLiveAppointments());
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Chức năng xem chi tiết lịch khám đang được hoàn thiện.',
                ),
              ),
            );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _usesLiveData
        ? context.watch<AppointmentController?>()
        : null;
    _syncLiveItems(controller);
    _loadLiveAppointments();
    final state = _usesLiveData
        ? (controller?.appointmentsStatus ?? ViewState.empty)
        : widget.viewState;
    final errorMessage = _usesLiveData
        ? controller?.appointmentsErrorMessage
        : widget.errorMessage;
    final onRetry = _usesLiveData
        ? () => _loadLiveAppointments(force: true)
        : widget.onRetry;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: PatientHomeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 80 * MediaQuery.textScalerOf(context).scale(1),
            title: const Text(
              'Lịch sử đặt khám',
              maxLines: 2,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OutlinedButton.icon(
                  onPressed: _filterOpen ? null : _filter,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Lọc'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          for (final tab in AppointmentHistoryTab.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tab.label),
                                selected: _tab == tab,
                                onSelected: (_) => setState(() => _tab = tab),
                                showCheckmark: false,
                                selectedColor: AppColors.textOnPrimary,
                                backgroundColor: AppColors.primarySoft,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                                labelStyle: TextStyle(
                                  color: _tab == tab
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.isDemo)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Text(
                          'Dữ liệu minh họa — không phải lịch hẹn thật của tài khoản.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    if (_range != null || _specialty != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          [
                            if (_range != null)
                              '${HealthRecordsDateFilter.format(_range!.start)} – ${HealthRecordsDateFilter.format(_range!.end)}',
                            if (_specialty != null)
                              _scoped
                                      .where(
                                        (item) =>
                                            item.appointment.specialtyId ==
                                            _specialty,
                                      )
                                      .map((item) => item.specialtyName)
                                      .firstOrNull ??
                                  'Chuyên khoa đã chọn',
                          ].join(' • '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    Expanded(
                      child: _content(
                        context,
                        state: state,
                        errorMessage: errorMessage,
                        onRetry: onRetry,
                      ),
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
}
