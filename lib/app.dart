import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/themes/app_theme.dart';
import 'features/appointments/data/datasources/appointment_firebase_datasource.dart';
import 'features/appointments/data/repositories/appointment_repository_impl.dart';
import 'features/appointments/data/repositories/booking_repository_impl.dart';
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
import 'features/onboarding/data/datasources/app_preferences.dart';
import 'features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'features/onboarding/presentation/pages/splash_page.dart';
import 'features/profile/data/datasources/patient_firebase_datasource.dart';
import 'features/profile/data/repositories/patient_repository_impl.dart';
import 'features/specialties/data/datasources/specialty_firebase_datasource.dart';
import 'features/specialties/data/repositories/specialty_repository_impl.dart';

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
        ChangeNotifierProvider(
          create: (_) {
            final repository = BookingRepositoryImpl(
              specialtyRepository: SpecialtyRepositoryImpl(
                SpecialtyFirebaseDatasource(),
              ),
              doctorRepository: DoctorRepositoryImpl(
                DoctorFirebaseDatasource(),
              ),
              workScheduleRepository: WorkScheduleRepositoryImpl(
                WorkScheduleFirebaseDatasource(),
              ),
              timeSlotRepository: TimeSlotRepositoryImpl(
                TimeSlotFirebaseDatasource(),
              ),
              appointmentRepository: AppointmentRepositoryImpl(
                AppointmentFirebaseDatasource(),
              ),
              patientRepository: PatientRepositoryImpl(
                PatientFirebaseDatasource(),
              ),
            );
            return AppointmentController(
              bookingRepository: repository,
              bookAppointmentUseCase: BookAppointment(repository),
            );
          },
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
