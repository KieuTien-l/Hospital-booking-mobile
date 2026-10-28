import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'features/home/domain/repositories/doctor_workspace_repository.dart';
import 'features/home/data/repositories/demo_doctor_workspace_repository.dart';
import 'features/home/data/repositories/http_doctor_workspace_repository.dart';
import 'features/home/data/repositories/unconfigured_doctor_workspace_repository.dart';

import 'features/admin/presentation/controllers/admin_appointment_controller.dart';
import 'features/admin/presentation/controllers/admin_dashboard_controller.dart';
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
import 'features/payments/data/datasources/patient_payment_firebase_datasource.dart';
import 'features/payments/data/repositories/patient_payment_repository_impl.dart';
import 'features/payments/domain/repositories/patient_payment_repository.dart';
import 'features/payments/presentation/controllers/patient_payment_controller.dart';

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
import 'features/onboarding/presentation/pages/splash_page.dart';
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
import 'features/chatbot/data/repositories/worker_chatbot_repository.dart';
import 'features/chatbot/domain/repositories/chatbot_repository.dart';
import 'features/chatbot/presentation/controllers/chatbot_controller.dart';

class App extends StatelessWidget {
  const App({super.key});

  static const _doctorApiBaseUrl = String.fromEnvironment(
    'DOCTOR_API_BASE_URL',
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DoctorWorkspaceRepository>(
          create: (_) =>
              const bool.fromEnvironment(
                'DOCTOR_DEMO',
                defaultValue: !kReleaseMode,
              )
              ? const DemoDoctorWorkspaceRepository()
              : _doctorApiBaseUrl.isEmpty
              ? const UnconfiguredDoctorWorkspaceRepository()
              : HttpDoctorWorkspaceRepository(
                  baseUrl: _doctorApiBaseUrl,
                  tokenProvider: (userId) async {
                    final user = FirebaseAuth.instance.currentUser;
                    return user?.uid == userId ? user!.getIdToken() : null;
                  },
                  onUnauthorized: (userId) async {
                    if (FirebaseAuth.instance.currentUser?.uid == userId) {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                ),
          dispose: (_, repository) {
            if (repository is HttpDoctorWorkspaceRepository) {
              repository.dispose();
            }
          },
        ),
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
        Provider<ChatbotRepository>(create: (_) => WorkerChatbotRepository()),
        Provider<TestResultRepository>(
          create: (_) => TestResultRepositoryImpl(
            TestResultFirebaseDatasource(FirebaseFirestore.instance),
          ),
        ),
        Provider<FeedbackRepository>(
          create: (_) => FeedbackRepositoryImpl(
            FeedbackFirebaseDatasource(FirebaseFirestore.instance),
          ),
        ),
        Provider<PatientPaymentRepository>(
          create: (_) => PatientPaymentRepositoryImpl(
            PatientPaymentFirebaseDatasource(FirebaseFirestore.instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              TestResultController(context.read<TestResultRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              FeedbackController(context.read<FeedbackRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => PatientPaymentController(
            context.read<PatientPaymentRepository>(),
          ),
        ),
        Provider<HealthRecordRepository>(
          create: (_) => HealthRecordRepositoryImpl(
            HealthRecordFirebaseDatasource(FirebaseFirestore.instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              HealthRecordController(context.read<HealthRecordRepository>()),
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
          create: (context) => AdminDashboardController(
            specialtyRepository: context.read<SpecialtyRepository>(),
            doctorRepository: context.read<DoctorRepository>(),
            appointmentRepository: context.read<AppointmentRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminAppointmentController(
            appointmentRepository: context.read<AppointmentRepository>(),
            doctorRepository: context.read<DoctorRepository>(),
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
        ChangeNotifierProvider(
          create: (context) =>
              ChatbotController(context.read<ChatbotRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'HealWay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashPage(),
      ),
    );
  }
}
