// SDK interfaces are faked here to inspect repository mapping and transactions.
// Authorization is tested separately against the real Firebase emulators.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/admin/data/repositories/admin_management_repository_impl.dart';
import 'package:flutter_application_4/features/admin/data/repositories/admin_account_repository_impl.dart';
import 'package:flutter_application_4/features/doctors/data/datasources/doctor_firebase_datasource.dart';
import 'package:flutter_application_4/features/specialties/data/datasources/specialty_firebase_datasource.dart';
import 'package:flutter_application_4/features/home/data/repositories/firestore_doctor_workspace_repository.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/doctors/data/repositories/doctor_repository_impl.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/work_schedule_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/time_slot_repository.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/appointment_repository.dart';

void main() {
  late _Store store;
  setUp(() {
    store = _Store({
      'CHUYEN_KHOA/one': {
        'name': 'Nội',
        'description': '',
        'status': 'ACTIVE',
        'isActive': true,
      },
      'CHUYEN_KHOA/two': {
        'name': 'Ngoại',
        'status': 'ACTIVE',
        'isActive': true,
      },
      'CHUYEN_KHOA/archived': {'name': 'Cũ', 'status': 'ARCHIVED'},
      'BAC_SI/doctor': {
        'userId': 'user',
        'fullName': 'Bác sĩ A',
        'specialtyId': 'one',
        'status': 'ACTIVE',
        'yearsOfExperience': 4,
        'consultationFee': 120000,
        'acceptingBookings': false,
        'address': 'Địa chỉ',
        'gender': 'Nữ',
        'dateOfBirth': Timestamp.fromDate(DateTime(1980)),
      },
      'BAC_SI/retired': {
        'userId': 'old',
        'fullName': 'Bác sĩ cũ',
        'specialtyId': 'one',
        'status': 'INACTIVE',
      },
      'LICH_LAM_VIEC/schedule': {
        'doctorId': 'doctor',
        'workDate': Timestamp.fromDate(DateTime(2026, 11, 2)),
        'startTime': '08:00',
        'endTime': '12:00',
        'status': 'ACTIVE',
      },
    });
  });

  test(
    'account review writes an audit with the reviewer in the same transaction',
    () async {
      store.rows['TAI_KHOAN/pending'] = {
        'role': 'patient',
        'status': 'PENDING',
        'isActive': false,
        'email': 'pending@example.com',
        'fullName': 'Chờ duyệt',
        'phone': '',
      };
      final repository = AdminAccountRepositoryImpl(
        firestore: store,
        reviewerIdProvider: () => 'admin',
      );
      final result = await repository.approveAccount('pending');
      expect(result.status, 'APPROVED');
      final audit = store.rows['NHAT_KY_ADMIN/account-review-pending']!;
      expect(audit['actorId'], 'admin');
      expect(audit['targetId'], 'pending');
      expect(audit['before'], {'status': 'PENDING', 'isActive': false});
      expect(audit['after'], {'status': 'APPROVED', 'isActive': true});
      expect(audit['createdAt'], isA<Timestamp>());
      await expectLater(
        repository.approveAccount('pending'),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'ADM-05: maps document ids, missing fields and inactive history correctly',
    () async {
      final source = DoctorFirebaseDatasource(firestore: store);
      expect((await source.getDoctors()).single.id, 'doctor');
      expect((await source.getAllDoctors()), hasLength(2));
      expect((await source.getDoctorById(' retired '))?.isActive, isFalse);
      expect(await source.getDoctorById('missing'), isNull);
      expect((await source.getDoctorsBySpecialty(' one ')).single.email, '');
      expect(await source.getDoctorsBySpecialty(''), isEmpty);
      expect((await source.getDoctorByUserId('user'))?.id, 'doctor');
      store.rows['BAC_SI/duplicate'] = {...store.rows['BAC_SI/doctor']!};
      await expectLater(source.getDoctorByUserId('user'), throwsStateError);
    },
  );

  test('ADM-08: specialist stream excludes archived records and writes canonical data', () async {
    final source = SpecialtyFirebaseDatasource(firestore: store);
    final active = await source.watchSpecialties().first;
    expect(active.map((s) => s.id), ['one', 'two']);
    final all = await source.watchAllSpecialties().first;
    expect(all, hasLength(3));
    final repository = AdminManagementRepositoryImpl(firestore: store);
    await repository.saveSpecialty(active.first);
    expect(store.rows['CHUYEN_KHOA/one']!['name'], 'Nội');
    expect(store.rows['CHUYEN_KHOA/one']!['status'], 'ACTIVE');
    expect(store.rows['CHUYEN_KHOA/one']!.containsKey('id'), isFalse);
  });

  test('ADM-05: saving or transferring a doctor preserves profile and booking settings', () async {
    final repository = AdminManagementRepositoryImpl(firestore: store);
    final doctor = (await DoctorFirebaseDatasource(firestore: store)
        .getDoctorById('doctor'))!;
    await repository.saveDoctor(doctor);
    final transferred = await repository.transferDoctorToSpecialty(
      doctorId: 'doctor',
      targetSpecialtyId: 'two',
    );
    expect(transferred.specialtyId, 'two');
    expect(transferred.acceptingBookings, isFalse);
    expect(transferred.address, 'Địa chỉ');
    expect(transferred.gender, 'Nữ');
    expect(transferred.dateOfBirth, doctor.dateOfBirth);
    expect(store.rows['BAC_SI/doctor']!['userId'], 'user');
  });

  test('ADM-18: Firebase request retries reuse id, keep metadata and reject changed payload', () async {
    final repository = FirestoreDoctorWorkspaceRepository(
      firestore: store,
      doctorRepository: DoctorRepositoryImpl(
        DoctorFirebaseDatasource(firestore: store),
      ),
      workScheduleRepository: _Schedules(),
      timeSlotRepository: _Slots(),
      appointmentRepository: _Appointments(),
    );
    DoctorReportDraft draft(String reason) => DoctorReportDraft(
      type: 'Bận đột xuất',
      scheduleId: 'schedule',
      date: DateTime(2026, 11, 2),
      reason: reason,
      description: 'Mô tả',
      requestId: 'stable-id',
    );
    final first = await repository.submitReport(
      userId: 'user',
      draft: draft('Lý do'),
    );
    final again = await repository.submitReport(
      userId: 'user',
      draft: draft('Lý do'),
    );
    expect(first.id, again.id);
    expect(first.senderId, 'user');
    expect(first.doctorId, 'doctor');
    expect(first.status, DoctorReportStatus.pending);
    expect(first.createdAt, isNotNull);
    expect((await repository.loadReports(userId: 'user')), hasLength(1));
    await expectLater(
      repository.submitReport(userId: 'user', draft: draft('Đổi nội dung')),
      throwsStateError,
    );
  });
}

class _Store extends Fake implements FirebaseFirestore {
  _Store(this.rows);
  final Map<String, Map<String, dynamic>> rows;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> action, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => action(_Transaction(this));
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, store.rows[path]);
}

class _Snapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.reference, this.value);
  @override
  final _Document reference;
  final Map<String, dynamic>? value;
  @override
  String get id => reference.id;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic> data() => value ?? {};
}

class _QueryResult extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _QueryResult(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path, [this.filters = const {}]);
  final _Store store;
  @override
  final String path;
  final Map<String, Object?> filters;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/${path ?? 'generated'}');
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Collection(store, path, {...filters, field as String: isEqualTo});
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QueryResult([
    for (final entry in store.rows.entries)
      if (entry.key.startsWith('$path/') &&
          filters.entries.every((f) => entry.value[f.key] == f.value))
        _Snapshot(_Document(store, entry.key), entry.value),
  ]);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.fromFuture(get());
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final _Store store;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async => _Snapshot(
    documentReference as _Document,
    store.rows[documentReference.path],
  ) as DocumentSnapshot<T>;
  Map<String, dynamic> _resolved(Map<String, dynamic> data) => {
    for (final e in data.entries)
      e.key: e.value is FieldValue ? Timestamp.now() : e.value,
  };
  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    store.rows[documentReference.path] = {
      ...?store.rows[documentReference.path],
      ..._resolved(data as Map<String, dynamic>),
    };
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    store.rows[documentReference.path]!.addAll(
      _resolved(Map<String, dynamic>.from(data)),
    );
    return this;
  }
}

class _Schedules extends Fake implements WorkScheduleRepository {}

class _Slots extends Fake implements TimeSlotRepository {}

class _Appointments extends Fake implements AppointmentRepository {}
