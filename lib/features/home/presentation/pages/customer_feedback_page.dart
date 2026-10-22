import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../feedbacks/domain/entities/feedback_info.dart';
import '../../../feedbacks/presentation/controllers/feedback_controller.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../models/feedback_ui_model.dart';
import '../widgets/feedback_form.dart';
import '../widgets/feedback_history_card.dart';
import '../widgets/patient_home_background.dart';
import 'feedback_detail_page.dart';

class CustomerFeedbackPage extends StatefulWidget {
  const CustomerFeedbackPage({
    super.key,
    this.history = const [],
    this.onSubmit,
    this.profileSelector,
  });
  final List<FeedbackUiModel> history;

  /// Optional live persistence adapter.  When absent, the page keeps using
  /// the app-level [FeedbackController].
  final Future<void> Function(FeedbackUiModel draft)? onSubmit;

  /// A live data source can provide a patient-profile picker without
  /// replacing the established feedback UI.
  final Widget? profileSelector;
  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  FeedbackCategory? _category;
  FeedbackStatus? _filter;
  int? _rating;
  bool _submitting = false;
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabs.indexIsChanging || _tabs.index != 1) return;
    _loadHistory(force: true);
  }

  void _loadHistory({bool force = false}) {
    final patient = context.read<PatientProfileController?>()?.patient;
    final controller = context.read<FeedbackController?>();
    if (patient == null ||
        controller == null ||
        (!force && _loadedPatientId == patient.id)) {
      return;
    }
    _loadedPatientId = patient.id;
    controller.loadFeedbacks(patient.id);
  }

  void _retryHistory() {
    _loadHistory(force: true);
  }

  FeedbackCategory _categoryFrom(String? value) {
    return FeedbackCategory.values.firstWhere(
      (category) => category.name == value || category.label == value,
      orElse: () => FeedbackCategory.suggestion,
    );
  }

  FeedbackUiModel _toUiModel(FeedbackInfo feedback) {
    final createdAt = feedback.createdAt;
    final dateLabel = createdAt == null
        ? 'Vừa gửi'
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    return FeedbackUiModel(
      title: feedback.title?.trim().isNotEmpty == true
          ? feedback.title!.trim()
          : 'Phản hồi của bạn',
      content: feedback.content,
      category: _categoryFrom(feedback.category),
      dateLabel: dateLabel,
      status: FeedbackStatus.pending,
      rating: feedback.rating.round(),
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (widget.onSubmit != null) {
      FocusScope.of(context).unfocus();
      setState(() => _submitting = true);
      try {
        await widget.onSubmit!(
          FeedbackUiModel(
            title: _title.text.trim(),
            content: _content.text.trim(),
            category: _category!,
            rating: _rating,
            dateLabel: 'Vừa gửi',
            status: FeedbackStatus.pending,
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể gửi phản hồi. Vui lòng thử lại.'),
            ),
          );
        }
        return;
      }
      if (mounted) await _completeSubmit();
      return;
    }
    final patient = context.read<PatientProfileController?>()?.patient;
    final controller = context.read<FeedbackController?>();
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng cập nhật hồ sơ bệnh nhân trước khi gửi phản hồi.',
          ),
        ),
      );
      return;
    }
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chức năng phản hồi chưa sẵn sàng.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final saved = await controller.submitFeedback(
      FeedbackInfo(
        id: '',
        patientId: patient.id,
        title: _title.text.trim(),
        category: _category!.name,
        content: _content.text.trim(),
        rating: _rating!.toDouble(),
      ),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ??
                'Không thể gửi phản hồi. Vui lòng thử lại.',
          ),
        ),
      );
      return;
    }
    await controller.loadFeedbacks(patient.id);
    if (!mounted) return;
    await _completeSubmit();
  }

  Future<void> _completeSubmit() async {
    _title.clear();
    _content.clear();
    setState(() {
      _submitting = false;
      _category = null;
      _rating = null;
    });
    final showHistory = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppColors.textOnPrimary,
        ),
        title: const Text('Phản hồi đã được gửi'),
        content: const Text(
          'Cảm ơn bạn đã chia sẻ ý kiến. Phản hồi đã được lưu và đang chờ tiếp nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xem lịch sử'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      if (showHistory == true) _filter = null;
    });
    if (showHistory == true) _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProfileController?>()?.patient;
    final controller = context.watch<FeedbackController?>();
    if (patient != null && _tabs.index == 1 && _loadedPatientId != patient.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
    final hasCurrentHistory =
        patient != null && controller?.patientId == patient.id;
    final persistedHistory = hasCurrentHistory
        ? controller!.feedbacks.map(_toUiModel)
        : const <FeedbackUiModel>[];
    final history = [
      ...widget.history,
      ...persistedHistory,
    ].where((item) => _filter == null || item.status == _filter).toList();
    final loadingHistory =
        patient != null && controller != null && !hasCurrentHistory;
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
            title: const Text(
              'Lắng nghe khách hàng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: AppColors.textOnPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryDark,
              tabs: const [
                Tab(text: 'Chia sẻ phản hồi'),
                Tab(text: 'Lịch sử'),
              ],
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    Column(
                      children: [
                        if (widget.profileSelector case final selector?)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: selector,
                          ),
                        Expanded(
                          child: FeedbackForm(
                            formKey: _formKey,
                            titleController: _title,
                            contentController: _content,
                            category: _category,
                            rating: _rating,
                            submitting: _submitting,
                            onCategoryChanged: (value) =>
                                setState(() => _category = value),
                            onRatingChanged: (value) =>
                                setState(() => _rating = value),
                            onSubmit: _submit,
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      key: const PageStorageKey('feedback-history'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Các phản hồi bạn đã gửi đến HealWay.'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Tất cả'),
                              selected: _filter == null,
                              onSelected: (_) => setState(() => _filter = null),
                            ),
                            for (final status in FeedbackStatus.values)
                              ChoiceChip(
                                label: Text(status.label),
                                selected: _filter == status,
                                onSelected: (_) =>
                                    setState(() => _filter = status),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (loadingHistory || controller?.isLoading == true)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (!loadingHistory &&
                            controller?.isHistoryUnavailable == true)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 44,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Mất kết nối. Vui lòng mở mạng rồi thử lại.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!loadingHistory &&
                            controller?.isHistoryUnavailable == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: OutlinedButton.icon(
                              onPressed: _retryHistory,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ),
                        if (!loadingHistory &&
                            controller?.isError == true &&
                            controller?.isHistoryUnavailable != true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller?.errorMessage ??
                                      'Không thể tải lịch sử phản hồi.',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _retryHistory,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        if (!loadingHistory &&
                            controller?.isHistoryUnavailable != true &&
                            history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Chưa có chia sẻ phản hồi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Những phản hồi bạn đã gửi sẽ được hiển thị tại đây.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _tabs.animateTo(0),
                                  child: const Text('Thêm chia sẻ phản hồi'),
                                ),
                              ],
                            ),
                          ),
                        for (final item in history)
                          FeedbackHistoryCard(
                            feedback: item,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FeedbackDetailPage(feedback: item),
                              ),
                            ),
                          ),
                      ],
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
