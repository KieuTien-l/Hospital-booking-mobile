/// Presentation-only values, independent of persistence and booking.
class DoctorDetailUiModel {
  const DoctorDetailUiModel({
    required this.id,
    required this.name,
    required this.specialty,
    this.avatarUrl,
    this.qualification,
    this.gender,
    this.position,
    this.introduction,
    this.isDemo = false,
    this.schedule = const [],
    this.education = const [],
    this.clinicalExperience = const [],
    this.teachingExperience = const [],
    this.associations = const [],
    this.research = const [],
  });

  final String id;
  final String name;
  final String specialty;
  final String? avatarUrl;
  final String? qualification;
  final String? gender;
  final String? position;
  final String? introduction;
  final bool isDemo;
  final List<DoctorScheduleUi> schedule;
  final List<DoctorMilestoneUi> education;
  final List<DoctorMilestoneUi> clinicalExperience;
  final List<DoctorMilestoneUi> teachingExperience;
  final List<String> associations;
  final List<DoctorMilestoneUi> research;
}

class DoctorScheduleUi {
  const DoctorScheduleUi({
    required this.day,
    required this.session,
    required this.location,
  });
  final String day;
  final String session;
  final String location;
}

class DoctorMilestoneUi {
  const DoctorMilestoneUi({
    required this.period,
    required this.title,
    this.description,
  });
  final String period;
  final String title;
  final String? description;
}
