class TestResult {
  const TestResult({
    required this.id,
    required this.patientId,
    required this.testName,
    required this.resultDescription,
    required this.testDate,
    this.attachmentUrl,
  });

  final String id;
  final String patientId;
  final String testName;
  final String resultDescription;
  final DateTime testDate;
  final String? attachmentUrl;
}

