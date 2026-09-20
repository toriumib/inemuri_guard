import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Lock onto one person. Never silently switch to a bystander after losing them.
/// Starting with multiple faces waits for a single unambiguous target.
class FaceTarget {
  int? _trackingId;
  bool _locked = false;
  Face? select(List<Face> faces) {
    if (!_locked) {
      if (faces.length != 1 || faces.single.trackingId == null) return null;
      _trackingId = faces.single.trackingId;
      _locked = true;
    }
    for (final face in faces) {
      if (face.trackingId == _trackingId) return face;
    }
    return null;
  }

  void reset() {
    _locked = false;
    _trackingId = null;
  }
}
