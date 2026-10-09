import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../doctors/presentation/controllers/schedule_controller.dart';
import 'booking_confirm_page.dart';

class BookingSchedulePage extends StatefulWidget {
  const BookingSchedulePage({super.key, required this.doctor});

  final Doctor doctor;

  @override
  State<BookingSchedulePage> createState() => _BookingSchedulePageState();
}

class _BookingSchedulePageState extends State<BookingSchedulePage> {
  late List<DateTime> _dates;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dates = List.generate(14, (index) => DateTime.now().add(Duration(days: index)));
    _selectedDate = DateTime(_dates.first.year, _dates.first.month, _dates.first.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ScheduleController>();
      controller.selectDoctor(widget.doctor);
      controller.selectDate(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chọn thời gian'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 80,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _dates.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final date = _dates[index];
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = DateTime(date.year, date.month, date.day);
                      });
                      context.read<ScheduleController>().selectDate(_selectedDate);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryDark : AppColors.border,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E', 'vi').format(date),
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<ScheduleController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const AppLoadingWidget(message: 'Đang tải lịch trống...');
                }
                if (controller.isError) {
                  return AppErrorWidget(
                    message: controller.errorMessage ?? 'Lỗi không xác định',
                    onRetry: () => controller.loadSchedule(),
                  );
                }
                final slots = controller.availableTimeSlots;
                if (slots.isEmpty) {
                  return const AppEmptyWidget(message: 'Không có lịch trống cho ngày này.', icon: Icons.calendar_today_outlined);
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    WorkSchedule? workSchedule;
                    for (final schedule in controller.workSchedules) {
                      if (schedule.id == slot.workScheduleId) {
                        workSchedule = schedule;
                        break;
                      }
                    }
                    final selectedSchedule = workSchedule;
                    return InkWell(
                      onTap: selectedSchedule == null
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingConfirmPage(
                              doctor: widget.doctor,
                              date: _selectedDate,
                              timeSlot: slot,
                              workSchedule: selectedSchedule,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryLight),
                        ),
                        child: Text(
                          '${slot.startTime} - ${slot.endTime}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
