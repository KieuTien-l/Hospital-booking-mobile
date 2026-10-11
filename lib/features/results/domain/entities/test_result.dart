class TestResult {
  const TestResult({
    required this.id,
    required this.patientId,
    required this.testName,
    required this.resultDescription,
    required this.testDate,
    this.resultType = 'Khác',
    this.conclusion,
    this.referenceRange,
    this.doctorName,
    this.attachmentUrl,
  });

  final String id;
  final String patientId;
  final String testName;
  final String resultDescription;
  final DateTime testDate;
  final String resultType;
  final String? conclusion;
  final String? referenceRange;
  final String? doctorName;
  final String? attachmentUrl;
}
