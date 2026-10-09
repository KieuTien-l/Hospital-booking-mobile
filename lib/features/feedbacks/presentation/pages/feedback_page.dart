import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../../domain/entities/feedback_info.dart';
import '../controllers/feedback_controller.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _contentController = TextEditingController();
  double _rating = 5;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit(String patientId) async {
    final saved = await context.read<FeedbackController>().submitFeedback(
      FeedbackInfo(
        id: '',
        patientId: patientId,
        content: _contentController.text,
        rating: _rating,
      ),
    );
    if (!mounted || !saved) return;
    _contentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cảm ơn phản hồi của bạn!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lắng nghe khách hàng'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: patient == null
          ? AppEmptyWidget(
              message: profile?.isError == true
                  ? (profile?.errorMessage ?? 'Không thể tải hồ sơ bệnh nhân.')
                  : 'Vui lòng cập nhật hồ sơ bệnh nhân trước khi gửi phản hồi.',
              icon: Icons.person_off_outlined,
              onRetry: profile?.isError == true ? profile?.refreshPatient : null,
            )
          : Consumer<FeedbackController>(
              builder: (context, controller, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Ý kiến của bạn giúp chúng tôi cải thiện chất lượng phục vụ.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mức độ hài lòng',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Slider(
                    value: _rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _rating.toStringAsFixed(0),
                    onChanged: controller.isLoading
                        ? null
                        : (value) => setState(() => _rating = value),
                  ),
                  Text('${_rating.toStringAsFixed(0)}/5 sao'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _contentController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung phản hồi',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (controller.isError) ...[
                    const SizedBox(height: 12),
                    Text(
                      controller.errorMessage ?? 'Không thể gửi phản hồi.',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: controller.isLoading
                        ? null
                        : () => _submit(patient.id),
                    child: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Gửi phản hồi'),
                  ),
                ],
              ),
            ),
    );
  }
}
