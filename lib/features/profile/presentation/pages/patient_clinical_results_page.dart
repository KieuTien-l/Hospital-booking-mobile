import 'package:flutter/material.dart';

import '../../domain/entities/patient.dart';
import '../widgets/patient_results_view.dart';

class PatientClinicalResultsPage extends StatelessWidget {
  const PatientClinicalResultsPage({
    super.key,
    required this.patient,
    this.initialDate,
  });

  final Patient patient;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) => PatientResultsView(
    patient: patient,
    initialDate: initialDate,
    title: 'Kết quả cận lâm sàng',
    typeLabel: '▎ LOẠI CẬN LÂM SÀNG',
    typePickerTitle: 'Chọn loại cận lâm sàng',
    types: const [
      'Xét nghiệm',
      'Siêu âm',
      'X Quang',
      'CT Scan',
      'MRI',
      'Nội soi',
    ],
    emptyTitle: 'Không có kết quả!',
    emptyMessage: 'Vui lòng thử điều chỉnh bộ lọc năm hoặc chọn danh mục khác để xem kết quả.',
  );
}
