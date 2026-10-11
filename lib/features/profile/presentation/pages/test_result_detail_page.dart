import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../results/domain/entities/test_result.dart';
import '../../domain/entities/patient.dart';

class TestResultDetailPage extends StatelessWidget {
  const TestResultDetailPage({
    super.key,
    required this.patient,
    required this.result,
  });

  final Patient patient;
  final TestResult result;

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
          title: const Text('Chi tiết kết quả'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.biotech_outlined,
                          color: AppColors.primaryDark,
                          size: 34,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          result.testName.isEmpty
                              ? 'Kết quả chưa có tên'
                              : result.testName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          result.resultType,
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DetailRow(
                          label: 'Người bệnh',
                          value: patient.fullName,
                        ),
                        _DetailRow(
                          label: 'Ngày trả kết quả',
                          value: DateFormat('dd/MM/yyyy HH:mm')
                              .format(result.testDate),
                        ),
                        if (result.doctorName != null)
                          _DetailRow(
                            label: 'Bác sĩ phụ trách',
                            value: result.doctorName!,
                          ),
                        const Divider(height: 32),
                        _DetailSection(
                          label: 'Kết quả',
                          value: result.resultDescription.isEmpty
                              ? 'Chưa có mô tả kết quả.'
                              : result.resultDescription,
                        ),
                        if (result.referenceRange != null) ...[
                          const SizedBox(height: 18),
                          _DetailSection(
                            label: 'Chỉ số tham chiếu',
                            value: result.referenceRange!,
                          ),
                        ],
                        if (result.conclusion != null) ...[
                          const SizedBox(height: 18),
                          _DetailSection(
                            label: 'Kết luận',
                            value: result.conclusion!,
                          ),
                        ],
                        if (result.attachmentUrl != null) ...[
                          const SizedBox(height: 18),
                          const _DetailSection(
                            label: 'Tệp đính kèm',
                            value: 'Có tệp đính kèm trong hồ sơ kết quả.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(height: 1.5)),
    ],
  );
}
