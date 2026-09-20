import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/face_target.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';

void main() {
  late DrowsinessDetector d;
  late DateTime now;
  setUp(() {
    now = DateTime(2026);
    d = DrowsinessDetector()..clock = () => now;
    d.noteFaceSeen();
    d.ingestEyes(1, 1);
    d.ingestPose(0, 0, 0);
  });
  void feed(int count, {double eye = 1, double pitch = 0, int ms = 250}) {
    for (var i = 0; i < count; i++) {
      now = now.add(Duration(milliseconds: ms));
      d.ingestEyes(eye, eye);
      d.ingestPose(pitch, 0, 0);
    }
  }

  test('irregular frame times still complete the PERCLOS warmup', () {
    d.setThresholdSeconds(60);
    feed(200, ms: 251);
    feed(55, eye: 0, ms: 263);
    expect(d.eyeAlarm, isTrue);
  });
  test('PERCLOS weights time instead of dense frames', () {
    d.setThresholdSeconds(60);
    // Numerous closed frames cover little time; sparse open frames cover most.
    feed(100, eye: 0, ms: 10);
    feed(38, eye: 1, ms: 500);
    expect(d.perclos, lessThan(0.15));
    expect(d.eyeAlarm, isFalse);
  });
  test('unknown eyes after calibration are not closed eyes', () {
    for (var i = 0; i < 300; i++) {
      now = now.add(const Duration(milliseconds: 250));
      d.ingestEyes(null, 0);
      d.ingestPose(0, 0, 0);
    }
    expect(d.alarmFiring, isFalse);
    expect(d.eyesAvailable, isFalse);
    expect(d.perclos, 0);
    d.ingestEyes(1, 1);
    expect(d.eyesAvailable, isTrue);
  });
  test('open eyes cannot clear a posture alarm', () {
    feed(50, pitch: 40);
    expect(d.postureAlarm, isTrue);
    expect(d.eyeAlarm, isFalse);
    feed(16);
    expect(d.alarmFiring, isFalse);
  });
  test('simultaneous causes resolve independently', () {
    feed(30, eye: 0, pitch: 40);
    expect(d.eyeAlarm, isTrue);
    expect(d.postureAlarm, isTrue);
    feed(18, eye: 1, pitch: 40);
    expect(d.eyeAlarm, isFalse);
    expect(d.postureAlarm, isTrue);
    feed(16);
    expect(d.alarmFiring, isFalse);
  });
  test('camera stall resets elapsed time but does not clear an alarm', () {
    d.state = DetectorState.watching;
    feed(30, eye: 0);
    d.noteInput();
    now = now.add(const Duration(seconds: 4));
    d.checkInputHealth();
    expect(d.inputStalled, isTrue);
    expect(d.eyeAlarm, isTrue);
    expect(d.monitoringLabel, contains('停止'));
    d.noteInput();
    d.noteFaceSeen();
    feed(18);
    expect(d.eyeAlarm, isFalse);
    expect(d.inputStalled, isFalse);
  });
  test('missing input does not count toward consecutive closure', () {
    feed(10, eye: 0);
    now = now.add(const Duration(seconds: 10));
    feed(1, eye: 0);
    expect(d.eyeAlarm, isFalse);
    expect(d.closedFor, Duration.zero);
  });
  test('microphone stall shows failed state and retains existing alert', () {
    final mic = BreathingDetector()..state = MicState.listening;
    mic.alarmFiring = true;
    mic.noteInputFailure();
    expect(mic.state, MicState.failed);
    expect(mic.failure, isNotNull);
    expect(mic.alarmFiring, isTrue);
    mic.snooze();
    expect(mic.alarmFiring, isFalse);
    mic.dispose();
  });
  test('target follows ID rather than list order, never a bystander', () {
    Face face(int id) => Face(
      boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
      trackingId: id,
      landmarks: {},
      contours: {},
    );
    final target = FaceTarget();
    expect(target.select([face(1), face(2)]), isNull);
    expect(target.select([face(1)])?.trackingId, 1);
    expect(target.select([face(2), face(1)])?.trackingId, 1);
    expect(target.select([face(2)]), isNull);
    target.reset();
    expect(target.select([face(2)])?.trackingId, 2);
  });
}
