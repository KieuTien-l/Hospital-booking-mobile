import 'package:flutter/material.dart';

import '../models/feedback_ui_model.dart';
import '../validators/feedback_validators.dart';
import 'feedback_rating.dart';

class FeedbackForm extends StatelessWidget {
  const FeedbackForm({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.contentController,
    required this.category,
    required this.rating,
    required this.onCategoryChanged,
    required this.onRatingChanged,
    required this.onSubmit,
    required this.submitting,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FeedbackCategory? category;
  final int? rating;
  final ValueChanged<FeedbackCategory> onCategoryChanged;
  final ValueChanged<int?> onRatingChanged;
  final VoidCallback onSubmit;
  final bool submitting;
  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: SingleChildScrollView(
      key: const PageStorageKey('feedback-form'),
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ý kiến của bạn rất quan trọng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Chia sẻ trải nghiệm, góp ý hoặc những vấn đề bạn gặp phải để HealWay ngày càng hoàn thiện hơn.',
                  ),
                  SizedBox(height: 10),
                  Text('Chế độ demo • Phản hồi chưa được gửi đến hệ thống.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FormField<FeedbackCategory>(
            validator: (_) =>
                category == null ? 'Vui lòng chọn loại phản hồi.' : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loại phản hồi *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in FeedbackCategory.values)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: category == option,
                        onSelected: (_) {
                          field.didChange(option);
                          onCategoryChanged(option);
                        },
                      ),
                  ],
                ),
                if (field.hasError)
                  Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FeedbackRating(value: rating, onChanged: onRatingChanged),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('feedback-title'),
            controller: titleController,
            maxLength: 100,
            validator: FeedbackValidators.title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề phản hồi *',
              hintText: 'Nhập tiêu đề phản hồi của bạn',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('feedback-content'),
            controller: contentController,
            minLines: 5,
            maxLines: 10,
            maxLength: 1000,
            validator: FeedbackValidators.content,
            decoration: const InputDecoration(
              labelText: 'Nội dung phản hồi *',
              hintText: 'Hãy chia sẻ chi tiết trải nghiệm hoặc vấn đề bạn gặp phải...',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vui lòng không cung cấp mật khẩu, thông tin thẻ thanh toán hoặc dữ liệu y tế nhạy cảm trong nội dung phản hồi.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('feedback-submit'),
            onPressed: submitting ? null : onSubmit,
            child: const Text('Gửi phản hồi'),
          ),
        ],
      ),
    ),
  );
}
