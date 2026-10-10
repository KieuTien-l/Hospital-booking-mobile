import 'package:flutter/material.dart';

import '../../domain/entities/patient.dart';
import '../widgets/patient_results_view.dart';

class PatientImagingPage extends StatelessWidget {
  const PatientImagingPage({
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
    title: 'Hình ảnh chụp (PACS)',
    typeLabel: '▎ LOẠI HÌNH ẢNH CHỤP',
    typePickerTitle: 'Chọn loại hình ảnh chụp',
    types: const ['X Quang', 'CT Scan', 'MRI'],
    emptyTitle: 'Không có hình ảnh chụp!',
    emptyMessage: 'Vui lòng thử điều chỉnh bộ lọc năm hoặc chọn loại hình ảnh khác để xem kết quả.',
  );
}
