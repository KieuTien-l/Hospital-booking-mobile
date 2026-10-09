import 'doctor_detail_ui_model.dart';

/// Local fixtures only. Never represents a verified hospital profile.
abstract final class DoctorDetailDemoData {
  static DoctorDetailUiModel forDoctor({
    required String id,
    required String name,
    required String specialty,
    required String location,
    required String session,
    String? avatarUrl,
  }) {
    final morning = id == 'demo-morning';
    final afternoon = id == 'demo-afternoon';
    final known = morning || afternoon;
    return DoctorDetailUiModel(
      id: id,
      name: name,
      specialty: specialty,
      avatarUrl: avatarUrl,
      isDemo: true,
      qualification: morning
          ? 'Bác sĩ chuyên khoa II'
          : afternoon
          ? 'Thạc sĩ, Bác sĩ'
          : null,
      gender: morning
          ? 'Nam'
          : afternoon
          ? 'Nữ'
          : null,
      position: known ? 'Bác sĩ chuyên khoa' : null,
      introduction: known
          ? 'Thăm khám, tư vấn và theo dõi điều trị trong chuyên khoa $specialty. Chú trọng lắng nghe và hướng dẫn người bệnh chăm sóc sức khỏe.'
          : null,
      schedule: [
        DoctorScheduleUi(
          day: morning
              ? 'Thứ Hai'
              : afternoon
              ? 'Thứ Tư'
              : 'Ngày minh họa',
          session: session,
          location: location,
        ),
      ],
      education: morning
          ? const [
              DoctorMilestoneUi(
                period: '2022',
                title: 'Hoàn thành đào tạo chuyên khoa II',
              ),
              DoctorMilestoneUi(
                period: '2018',
                title: 'Hoàn thành đào tạo chuyên khoa I',
              ),
              DoctorMilestoneUi(
                period: '2015',
                title: 'Tốt nghiệp Bác sĩ Y khoa',
              ),
            ]
          : afternoon
          ? const [
              DoctorMilestoneUi(
                period: '2021',
                title: 'Hoàn thành chương trình Thạc sĩ Y khoa',
              ),
              DoctorMilestoneUi(
                period: '2016',
                title: 'Tốt nghiệp Bác sĩ Y khoa',
              ),
            ]
          : const [],
      clinicalExperience: known
          ? [
              DoctorMilestoneUi(
                period: morning ? '2018 – nay' : '2021 – nay',
                title: 'Bác sĩ tại cơ sở y tế minh họa A',
                description: 'Khám, tư vấn và theo dõi điều trị chuyên khoa.',
              ),
              DoctorMilestoneUi(
                period: morning ? '2015 – 2018' : '2016 – 2021',
                title: 'Bác sĩ tại cơ sở y tế minh họa B',
                description:
                    'Tham gia chăm sóc người bệnh và hoạt động chuyên môn.',
              ),
            ]
          : const [],
      teachingExperience: morning
          ? const [
              DoctorMilestoneUi(
                period: '2023 – nay',
                title: 'Hướng dẫn thực hành lâm sàng',
                description: 'Đơn vị đào tạo minh họa A.',
              ),
            ]
          : const [],
      associations: known
          ? const [
              'Hội chuyên ngành minh họa A',
              'Hiệp hội chuyên môn minh họa B',
            ]
          : const [],
      research: known
          ? [
              DoctorMilestoneUi(
                period: morning ? '2023' : '2024',
                title: 'Nghiên cứu minh họa về chăm sóc người bệnh ngoại trú',
                description: 'Vai trò: thành viên nhóm nghiên cứu. Khảo sát việc theo dõi và hướng dẫn chăm sóc sau thăm khám.',
              ),
            ]
          : const [],
    );
  }
}
