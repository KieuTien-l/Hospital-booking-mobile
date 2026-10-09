import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/appointments/data/datasources/appointment_firebase_datasource.dart';
import 'package:flutter_application_4/features/appointments/data/repositories/appointment_repository_impl.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/exceptions/booking_exception.dart';
import 'package:flutter_application_4/features/profile/data/datasources/patient_firebase_datasource.dart';
import 'package:flutter_application_4/features/profile/data/repositories/patient_repository_impl.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';

// Extend the SDK platform interfaces; use real app-facing Firestore objects.
// This store verifies payloads and rejection paths, not server concurrency.
class MemoryApp extends Fake implements FirebaseApp {
  MemoryApp(this.name);
  @override
  final String name;
}

class MemoryFirestore extends platform.FirebaseFirestorePlatform {
  MemoryFirestore() : super(appInstance: MemoryApp('booking-test-${++appId}'));
  static int appId = 0;
  final documents = <String, Map<String, dynamic>>{};
  int nextId = 0;

  FirebaseFirestore asFirestore() {
    platform.FirebaseFirestorePlatform.instance = this;
    return FirebaseFirestore.instanceFor(app: app);
  }

  @override
  platform.FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;

  @override
  platform.CollectionReferencePlatform collection(String collectionPath) =>
      MemoryCollection(this, collectionPath);

  @override
  platform.DocumentReferencePlatform doc(String documentPath) =>
      MemoryDocument(this, documentPath);

  platform.DocumentSnapshotPlatform snapshot(String path) =>
      platform.DocumentSnapshotPlatform(
        this,
        path,
        documents[path],
        platform.InternalSnapshotMetadata(
          hasPendingWrites: false,
          isFromCache: false,
        ),
      );

  @override
  Future<T?> runTransaction<T>(
    platform.TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = MemoryTransaction(this);
    final result = await transactionHandler(transaction);
    for (final write in transaction.writes) {
      write();
    }
    return result;
  }
}

class MemoryCollection extends platform.CollectionReferencePlatform {
  MemoryCollection(this.store, String path) : super(store, path);
  final MemoryFirestore store;

  @override
  platform.DocumentReferencePlatform doc([String? documentPath]) =>
      MemoryDocument(store, '$path/${documentPath ?? 'new-${++store.nextId}'}');
}

class MemoryDocument extends platform.DocumentReferencePlatform {
  MemoryDocument(this.store, String path) : super(store, path);
  final MemoryFirestore store;

  @override
  Future<platform.DocumentSnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async => store.snapshot(path);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.documents[path] = Map.of(data);
  }

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {
    if (!store.documents.containsKey(path)) {
      throw StateError('Missing document');
    }
    store.documents[path]!.addAll({
      for (final entry in data.entries)
        entry.key.components.join('.'): entry.value,
    });
  }
}

class MemoryTransaction extends platform.TransactionPlatform {
  MemoryTransaction(this.store);
  final MemoryFirestore store;
  final writes = <void Function()>[];

  @override
  Future<platform.DocumentSnapshotPlatform> get(String path) async =>
      store.snapshot(path);

  @override
  platform.TransactionPlatform set(
    String path,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) {
    writes.add(() => store.documents[path] = Map.of(data));
    return this;
  }

  @override
  platform.TransactionPlatform update(
    String path,
    Map<FieldPath, dynamic> data,
  ) {
    writes.add(
      () => store.documents[path]!.addAll({
        for (final entry in data.entries)
          entry.key.components.join('.'): entry.value,
      }),
    );
    return this;
  }
}

MemoryFirestore bookingStore() => MemoryFirestore()
  ..documents.addAll({
    'BAC_SI/doctor-1': {'specialtyId': 'specialty-1', 'status': 'ACTIVE'},
    'LICH_LAM_VIEC/schedule-1': {
      'doctorId': 'doctor-1',
      'workDate': DateTime(2026, 10, 5),
      'status': 'ACTIVE',
    },
    'CA_KHAM/slot-1': {
      'doctorId': 'doctor-1',
      'workScheduleId': 'schedule-1',
      'status': 'AVAILABLE',
      'startTime': '08:00',
      'endTime': '08:30',
      'capacity': 3,
      'bookedCount': 1,
    },
  });

Appointment request({int peopleCount = 1}) => Appointment(
  id: '',
  patientId: 'patient-1',
  doctorId: 'doctor-1',
  workScheduleId: 'schedule-1',
  timeSlotId: 'slot-1',
  reason: 'Checkup',
  peopleCount: peopleCount,
);

void main() {
  for (final count in [1, 2]) {
    test(
      'Booking $count patients keeps slot counters and persisted schema',
      () async {
        final store = bookingStore();
        final repository = AppointmentRepositoryImpl(
          AppointmentFirebaseDatasource(firestore: store.asFirestore()),
        );
        final saved = await repository.createAppointment(
          request(peopleCount: count),
        );
        final document = store.documents['LICH_HEN/${saved.id}']!;
        final slot = store.documents['CA_KHAM/slot-1']!;
        expect(saved.status, AppointmentStatus.pending);
        expect(document['patientId'], 'patient-1');
        expect(document['specialtyId'], 'specialty-1');
        expect(document['appointmentDate'], DateTime(2026, 10, 5));
        expect(document['startTime'], '08:00');
        expect(document['endTime'], '08:30');
        expect(document['symptoms'], 'Checkup');
        expect(document['peopleCount'], count);
        expect(slot['bookedCount'], 1 + count);
        expect(slot['status'], count == 2 ? 'BOOKED' : 'AVAILABLE');
        expect(slot['appointmentId'], saved.id);
      },
    );
  }

  final invalidCases = <String, void Function(MemoryFirestore)>{
    'missing doctor': (s) => s.documents.remove('BAC_SI/doctor-1'),
    'inactive doctor': (s) =>
        s.documents['BAC_SI/doctor-1']!['status'] = 'INACTIVE',
    'unavailable slot': (s) =>
        s.documents['CA_KHAM/slot-1']!['status'] = 'BOOKED',
    'mismatched schedule': (s) =>
        s.documents['CA_KHAM/slot-1']!['workScheduleId'] = 'other',
    'incomplete schedule': (s) =>
        s.documents['LICH_LAM_VIEC/schedule-1']!.remove('workDate'),
    'insufficient capacity': (s) =>
        s.documents['CA_KHAM/slot-1']!['capacity'] = 1,
  };
  for (final entry in invalidCases.entries) {
    test('Rejects ${entry.key} without writing appointment or slot', () async {
      final store = bookingStore();
      entry.value(store);
      final before = Map.of(store.documents['CA_KHAM/slot-1']!);
      final repository = AppointmentRepositoryImpl(
        AppointmentFirebaseDatasource(firestore: store.asFirestore()),
      );
      await expectLater(
        repository.createAppointment(request()),
        throwsA(isA<BookingException>()),
      );
      expect(
        store.documents.keys.where((key) => key.startsWith('LICH_HEN/')),
        isEmpty,
      );
      expect(store.documents['CA_KHAM/slot-1'], before);
    });
  }

  test(
    'Profile update preserves fields outside the editable payload',
    () async {
      final store = MemoryFirestore()
        ..documents['BENH_NHAN/patient-1'] = {
          'authUserId': 'user-1',
          'status': 'ACTIVE',
          'isActive': true,
          'customField': 'keep',
        };
      final repository = PatientRepositoryImpl(
        PatientFirebaseDatasource(firestore: store.asFirestore()),
      );
      const patient = Patient(
        id: 'patient-1',
        authUserId: 'user-1',
        fullName: 'Updated',
        phone: '0900000000',
        email: 'user@example.com',
        isActive: true,
      );
      await repository.updatePatient(patient);
      expect(store.documents['BENH_NHAN/patient-1']!['fullName'], 'Updated');
      expect(store.documents['BENH_NHAN/patient-1']!['customField'], 'keep');
      expect(store.documents['BENH_NHAN/patient-1']!['status'], 'ACTIVE');
    },
  );

  test('Cancelling a booking releases only its reservation', () async {
    final store = bookingStore();
    final repository = AppointmentRepositoryImpl(
      AppointmentFirebaseDatasource(firestore: store.asFirestore()),
    );
    final saved = await repository.createAppointment(request());

    await repository.cancelAppointment(saved.id, 'Changed plans');

    final slot = store.documents['CA_KHAM/slot-1']!;
    final appointment = store.documents['LICH_HEN/${saved.id}']!;
    expect(slot['bookedCount'], 1);
    expect(slot['status'], 'AVAILABLE');
    expect(slot['appointmentId'], saved.id);
    expect(slot['reservationCounts'], isEmpty);
    expect(appointment['status'], 'CANCELLED');
  });

  test('Rescheduling transfers the reservation between slots atomically', () async {
    final store = bookingStore()
      ..documents.addAll({
        'LICH_LAM_VIEC/schedule-2': {
          'doctorId': 'doctor-1',
          'workDate': DateTime(2026, 10, 6),
          'status': 'ACTIVE',
        },
        'CA_KHAM/slot-2': {
          'doctorId': 'doctor-1',
          'workScheduleId': 'schedule-2',
          'status': 'AVAILABLE',
          'startTime': '09:00',
          'endTime': '09:30',
          'capacity': 3,
          'bookedCount': 0,
          'reservationCounts': <String, int>{},
        },
      });
    final repository = AppointmentRepositoryImpl(
      AppointmentFirebaseDatasource(firestore: store.asFirestore()),
    );
    final saved = await repository.createAppointment(request());

    final moved = await repository.rescheduleAppointment(
      saved.id,
      'schedule-2',
      'slot-2',
      DateTime(2026, 10, 6),
      '09:00',
      '09:30',
    );

    expect(moved.timeSlotId, 'slot-2');
    expect(store.documents['CA_KHAM/slot-1']!['bookedCount'], 1);
    expect(store.documents['CA_KHAM/slot-1']!['reservationCounts'], isEmpty);
    expect(store.documents['CA_KHAM/slot-2']!['bookedCount'], 1);
    expect(store.documents['CA_KHAM/slot-2']!['reservationCounts'], {
      saved.id: 1,
    });
    expect(store.documents['LICH_HEN/${saved.id}']!['timeSlotId'], 'slot-2');
  });
}
