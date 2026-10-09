import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/health_records/data/datasources/health_record_firebase_datasource.dart';
import 'features/health_records/data/repositories/health_record_repository_impl.dart';
import 'features/health_records/domain/repositories/health_record_repository.dart';
import 'features/health_records/presentation/controllers/health_record_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/results/data/datasources/test_result_firebase_datasource.dart';
import 'features/results/data/repositories/test_result_repository_impl.dart';
import 'features/results/domain/repositories/test_result_repository.dart';
import 'features/results/presentation/controllers/test_result_controller.dart';
import 'features/feedbacks/data/datasources/feedback_firebase_datasource.dart';
import 'features/feedbacks/data/repositories/feedback_repository_impl.dart';
import 'features/feedbacks/domain/repositories/feedback_repository.dart';
import 'features/feedbacks/presentation/controllers/feedback_controller.dart';

import 'core/routes/auth_gate.dart';
import 'core/themes/app_theme.dart';
import 'features/appointments/data/datasources/appointment_firebase_datasource.dart';
import 'features/appointments/data/repositories/appointment_repository_impl.dart';
import 'features/appointments/data/repositories/booking_repository_impl.dart';
import 'features/appointments/domain/repositories/appointment_repository.dart';
import 'features/appointments/domain/repositories/booking_repository.dart';
import 'features/appointments/domain/usecases/book_appointment.dart';
import 'features/appointments/presentation/controllers/appointment_controller.dart';
import 'features/auth/data/datasources/auth_firebase_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/doctors/data/datasources/doctor_firebase_datasource.dart';
import 'features/doctors/data/datasources/time_slot_firebase_datasource.dart';
import 'features/doctors/data/datasources/work_schedule_firebase_datasource.dart';
import 'features/doctors/data/repositories/doctor_repository_impl.dart';
import 'features/doctors/data/repositories/time_slot_repository_impl.dart';
import 'features/doctors/data/repositories/work_schedule_repository_impl.dart';
import 'features/doctors/domain/repositories/doctor_repository.dart';
import 'features/doctors/domain/repositories/time_slot_repository.dart';
import 'features/doctors/domain/repositories/work_schedule_repository.dart';
import 'features/doctors/presentation/controllers/doctor_controller.dart';
import 'features/doctors/presentation/controllers/schedule_controller.dart';
import 'features/onboarding/data/datasources/app_preferences.dart';
import 'features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'features/profile/data/datasources/patient_firebase_datasource.dart';
import 'features/profile/data/repositories/patient_repository_impl.dart';
import 'features/profile/domain/repositories/patient_repository.dart';
import 'features/profile/presentation/controllers/patient_profile_controller.dart';
import 'features/specialties/data/datasources/specialty_firebase_datasource.dart';
import 'features/specialties/data/repositories/specialty_repository_impl.dart';
import 'features/specialties/domain/repositories/specialty_repository.dart';
import 'features/specialties/presentation/controllers/specialty_controller.dart';
import 'features/notifications/data/datasources/notification_firebase_datasource.dart';
import 'features/notifications/data/repositories/notification_repository_impl.dart';
import 'features/notifications/domain/repositories/notification_repository.dart';
import 'features/notifications/presentation/controllers/notification_controller.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (_) =>
              OnboardingController(OnboardingRepositoryImpl(AppPreferences())),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authRepo: AuthRepositoryImpl(AuthFirebaseDatasource()),
          ),
        ),
        Provider<SpecialtyRepository>(
          create: (_) => SpecialtyRepositoryImpl(SpecialtyFirebaseDatasource()),
        ),
        Provider<DoctorRepository>(
          create: (_) => DoctorRepositoryImpl(DoctorFirebaseDatasource()),
        ),
        Provider<WorkScheduleRepository>(
          create: (_) =>
              WorkScheduleRepositoryImpl(WorkScheduleFirebaseDatasource()),
        ),
        Provider<TimeSlotRepository>(
          create: (_) => TimeSlotRepositoryImpl(TimeSlotFirebaseDatasource()),
        ),
        Provider<PatientRepository>(
          create: (_) => PatientRepositoryImpl(PatientFirebaseDatasource()),
        ),
        Provider<AppointmentRepository>(
          create: (_) =>
              AppointmentRepositoryImpl(AppointmentFirebaseDatasource()),
        ),
        Provider<NotificationRepository>(
          create: (_) =>
              NotificationRepositoryImpl(NotificationFirebaseDatasource()),
        ),
        Provider<TestResultRepository>(
          create: (_) => TestResultRepositoryImpl(TestResultFirebaseDatasource(FirebaseFirestore.instance)),
        ),
        Provider<FeedbackRepository>(
          create: (_) => FeedbackRepositoryImpl(FeedbackFirebaseDatasource(FirebaseFirestore.instance)),
        ),
        ChangeNotifierProvider(
          create: (context) => TestResultController(context.read<TestResultRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => FeedbackController(context.read<FeedbackRepository>()),
        ),
        Provider<HealthRecordRepository>(
          create: (_) => HealthRecordRepositoryImpl(HealthRecordFirebaseDatasource(FirebaseFirestore.instance)),
        ),
        ChangeNotifierProvider(
          create: (context) => HealthRecordController(context.read<HealthRecordRepository>()),
        ),
        Provider<BookingRepository>(
          create: (context) => BookingRepositoryImpl(
            specialtyRepository: context.read<SpecialtyRepository>(),
            doctorRepository: context.read<DoctorRepository>(),
            workScheduleRepository: context.read<WorkScheduleRepository>(),
            timeSlotRepository: context.read<TimeSlotRepository>(),
            appointmentRepository: context.read<AppointmentRepository>(),
            patientRepository: context.read<PatientRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              SpecialtyController(context.read<SpecialtyRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              DoctorController(context.read<DoctorRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ScheduleController(
            workScheduleRepository: context.read<WorkScheduleRepository>(),
            timeSlotRepository: context.read<TimeSlotRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              PatientProfileController(context.read<PatientRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => AppointmentController(
            bookingRepository: context.read<BookingRepository>(),
            bookAppointmentUseCase: BookAppointment(
              context.read<BookingRepository>(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationController(context.read<NotificationRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'HealWay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}
