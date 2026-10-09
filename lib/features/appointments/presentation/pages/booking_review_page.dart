import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../models/booking_review_ui_model.dart';
import '../widgets/booking_review_patient_card.dart';
import '../widgets/booking_review_specialty_card.dart';
import '../widgets/booking_review_actions.dart';
import 'booking_success_page.dart';

/// Returns null after a successful booking, otherwise a safe message to show.
typedef BookingReviewSubmitter = Future<String?> Function(
  List<AppointmentConfirmationResult> items,
);

class BookingReviewPage extends StatefulWidget {
  const BookingReviewPage({
    super.key,
    required this.items,
    this.onRemoveSpecialty,
    this.onAddSpecialty,
    this.onConfirmBooking,
    this.onSubmitBooking,
  });
  final List<AppointmentConfirmationResult> items;
  final ValueChanged<AppointmentConfirmationResult>? onRemoveSpecialty;
  final VoidCallback? onAddSpecialty;
  final ValueChanged<List<AppointmentConfirmationResult>>? onConfirmBooking;
  final BookingReviewSubmitter? onSubmitBooking;

  @override
  State<BookingReviewPage> createState() => _BookingReviewPageState();
}

class _BookingReviewPageState extends State<BookingReviewPage> {
  bool _expanded = true;
  bool _submitting = false;

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _remove(AppointmentConfirmationResult item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chuyên khoa?'),
        content: Text(
          'Bạn muốn xóa ${item.information.specialtyName} khỏi danh sách đã chọn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (widget.onRemoveSpecialty != null) {
      widget.onRemoveSpecialty!(item);
    } else {
      _message('Chức năng xóa chuyên khoa sẽ được tích hợp sau.');
    }
  }

  Future<void> _confirmBooking() async {
    final submitter = widget.onSubmitBooking;
    if (submitter == null) {
      if (widget.onConfirmBooking != null) {
        widget.onConfirmBooking!(List.unmodifiable(widget.items));
      } else {
        _message(
          'Giao diện xác nhận đã hoàn thành. Chức năng đặt khám sẽ được tích hợp sau.',
        );
      }
      return;
    }

    setState(() => _submitting = true);
    final error = await submitter(List.unmodifiable(widget.items));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      _message(error);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => const BookingSuccessPage()),
      (route) => route.isFirst,
    );
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
          foregroundColor: AppColors.textOnPrimary,
          title: const Text(
            'Xác nhận thông tin',
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
                  const Text(
                    'Vui lòng kiểm tra kỹ thông tin đặt khám trước khi xác nhận.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  BookingReviewPatientCard(
                    information: widget.items.isEmpty
                        ? null
                        : widget.items.first.information,
                    expanded: _expanded,
                    onToggle: () => setState(() => _expanded = !_expanded),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chuyên khoa đã chọn (${widget.items.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.items.isEmpty)
                    const Text('Chưa có chuyên khoa đã chọn.'),
                  for (final item in widget.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: BookingReviewSpecialtyCard(
                        item: item,
                        onRemove: () => _remove(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: BookingReviewActions(
          total: bookingReviewTotalLabel(widget.items),
          onAddSpecialty:
              widget.onAddSpecialty ??
              () => _message('Chức năng thêm chuyên khoa chưa được hỗ trợ.'),
          onConfirm: widget.items.any(bookingReviewItemIsValid)
              ? _submitting
                    ? null
                    : _confirmBooking
              : null,
        ),
      ),
    ),
  );
}
