import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_4/features/appointments/data/models/appointment_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/doctor_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/work_schedule_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/time_slot_model.dart';
import 'package:flutter_application_4/features/home/data/repositories/http_doctor_workspace_repository.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/home/domain/repositories/doctor_workspace_repository.dart';

import 'doctor_test_support.dart';

void main() {
  final date = DateTime(2026, 10, 19);
  test('Day API sends bearer authorization, preserves date and parses the scoped projection', () async {
    final day = testDay(date);
    final repository = HttpDoctorWorkspaceRepository(
      baseUrl: 'https://backend.example.test/api/',
      tokenProvider: (id) async {
        expect(id, 'account');
        return 'test-token';
      },
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://backend.example.test/api/doctor/day?date=2026-10-19',
        );
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
            'doctor': DoctorModel.fromEntity(day.doctor).toJson(),
            'schedules': day.schedules
                .map(
                  (schedule) => WorkScheduleModel.fromEntity(schedule).toJson(),
                )
                .toList(),
            'slots': day.slots
                .map((slot) => TimeSlotModel.fromEntity(slot).toJson())
                .toList(),
            'bookings': day.bookings
                .map(
                  (booking) => {
                    'appointment': AppointmentModel.fromEntity(
                      booking.appointment,
                    ).toJson(),
                    'patientName': booking.patientName,
                    'birthYear': booking.birthYear,
                    'gender': booking.gender,
                  },
                )
                .toList(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(repository.dispose);
    final result = await repository.loadDay(userId: 'account', date: date);
    expect(result.doctor.userId, 'account');
    expect(result.totals.booked, 20);
    expect(result.bookings.first.patientName, 'Nguyễn Minh Anh');
  });
  test(
    '401 invalidates only the requesting session; 403 is an access error',
    () async {
      for (final code in [401, 403]) {
        final expired = <String>[];
        final repository = HttpDoctorWorkspaceRepository(
          baseUrl: 'https://backend.example.test',
          tokenProvider: (_) async => 'token',
          onUnauthorized: (id) async => expired.add(id),
          client: MockClient((_) async => http.Response('{}', code)),
        );
        await expectLater(
          repository.loadDay(userId: 'account', date: date),
          throwsA(isA<DoctorWorkspaceAccessException>()),
        );
        expect(expired, code == 401 ? ['account'] : isEmpty);
        repository.dispose();
      }
    },
  );
  test(
    'Missing endpoint or missing session never makes an anonymous request',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      final absent = HttpDoctorWorkspaceRepository(
        baseUrl: '',
        tokenProvider: (_) async => 'token',
        client: client,
      );
      expect(absent.canSubmitReports, isFalse);
      await expectLater(
        absent.loadDay(userId: 'account', date: date),
        throwsStateError,
      );
      final signedOut = HttpDoctorWorkspaceRepository(
        baseUrl: 'https://backend.example.test',
        tokenProvider: (_) async => null,
        client: client,
      );
      await expectLater(
        signedOut.loadDay(userId: 'account', date: date),
        throwsA(isA<DoctorWorkspaceAccessException>()),
      );
      expect(requests, 0);
      client.close();
    },
  );
  test('Report API sends an idempotency key without accepting a client doctor identity', () async {
    final repository = HttpDoctorWorkspaceRepository(
      baseUrl: 'https://backend.example.test',
      tokenProvider: (_) async => 'token',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Idempotency-Key'], 'request-1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['date'], '2026-10-19');
        expect(body['reason'], 'Lý do');
        expect(body.containsKey('doctorId'), isFalse);
        expect(body.containsKey('userId'), isFalse);
        return http.Response(
          jsonEncode({
            'id': 'report-1',
            'type': body['type'],
            'date': body['date'],
            'reason': body['reason'],
            'status': 'PENDING',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(repository.dispose);
    final result = await repository.submitReport(
      userId: 'account',
      draft: DoctorReportDraft(
        type: 'Bận đột xuất',
        scheduleId: 'schedule',
        date: date,
        reason: 'Lý do',
        description: 'Mô tả',
        requestId: 'request-1',
      ),
    );
    expect(result.status, DoctorReportStatus.pending);
  });
}
