import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
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
  final Future<void> Function(FeedbackUiModel draft)? onSubmit;
  final Widget? profileSelector;
  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final List<FeedbackUiModel> _history = List.of(widget.history);
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  FeedbackCategory? _category;
  FeedbackStatus? _filter;
  int? _rating;
  bool _submitting = false;
  @override
  void didUpdateWidget(covariant CustomerFeedbackPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onSubmit != null &&
        !identical(widget.history, oldWidget.history)) {
      _history
        ..clear()
        ..addAll(widget.history);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.onSubmit != null) {
      setState(() => _submitting = true);
      try {
        await widget.onSubmit!(
          FeedbackUiModel(
            title: _title.text.trim(),
            content: _content.text.trim(),
            category: _category!,
            rating: _rating,
            dateLabel: '',
            status: FeedbackStatus.pending,
          ),
        );
        if (mounted) {
          _filter = null;
          _title.clear();
          _content.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi phản hồi đến hệ thống.')),
          );
          _tabs.animateTo(1);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is StateError ? error.message : 'Chưa xác minh được kết quả gửi. Giữ nguyên nội dung để thử lại, tránh gửi trùng.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    setState(() {
      _submitting = true;
      _history.insert(
        0,
        FeedbackUiModel(
          title: _title.text.trim(),
          content: _content.text.trim(),
          category: _category!,
          rating: _rating,
          dateLabel: 'Phiên demo hiện tại',
          status: FeedbackStatus.pending,
        ),
      );
    });
    final showHistory = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppColors.textOnPrimary,
        ),
        title: const Text('Phản hồi mẫu đã được ghi nhận trong phiên demo'),
        content: const Text(
          'Đây là thao tác mô phỏng giao diện. Phản hồi chưa được gửi đến hệ thống.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xem lịch sử mẫu'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (showHistory == true) _filter = null;
    });
    if (showHistory == true) _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final history = _history
        .where((item) => _filter == null || item.status == _filter)
        .toList();
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
                    FeedbackForm(
                      formKey: _formKey,
                      titleController: _title,
                      contentController: _content,
                      category: _category,
                      rating: _rating,
                      submitting: _submitting,
                      isDemo: widget.onSubmit == null,
                      profileSelector: widget.profileSelector,
                      onCategoryChanged: (value) =>
                          setState(() => _category = value),
                      onRatingChanged: (value) =>
                          setState(() => _rating = value),
                      onSubmit: _submit,
                    ),
                    ListView(
                      key: const PageStorageKey('feedback-history'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          widget.onSubmit == null
                              ? 'Lịch sử mẫu • Chỉ lưu trong phiên demo, chưa gửi đến hệ thống.'
                              : 'Phản hồi đã gửi và tiến độ xử lý từ quản trị viên.',
                        ),
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
                        if (history.isEmpty)
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
                                  'Những phản hồi bạn đã gửi sẽ được hiển thị tại đây khi hệ thống được kết nối.',
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
