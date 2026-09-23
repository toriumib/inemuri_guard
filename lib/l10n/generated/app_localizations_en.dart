// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Drowsiness Guard';

  @override
  String get setupTitle => 'Quick setup';

  @override
  String get setupReady =>
      'Your face and eyes are visible. Now check the sound.';

  @override
  String get setupSteps =>
      '1. Tap “Start monitoring” below and allow the camera.\n2. Position your phone so your face and eyes are visible.\n3. Check the sound.';

  @override
  String get soundOutputFailed =>
      'Could not play the sound. Check the volume and audio output.';

  @override
  String get checkSound => 'Check the sound';

  @override
  String get saveFailed => 'Could not save. Please try again.';

  @override
  String get setupComplete => 'I heard it — finish setup';

  @override
  String get dismissForNow => 'Dismiss for now';

  @override
  String get setupHint =>
      'Next time, you can start with your saved settings. You can set up notifications and watch alerts later in Settings.';

  @override
  String get cameraRecoveryHint =>
      'Tap “Reconnect camera” below. Close any other app that is using the camera.';

  @override
  String get faceRecoveryHint =>
      'Keep only your face in view and improve the lighting. Restart monitoring when a different person uses the app.';

  @override
  String get eyeRecoveryHint =>
      'Adjust your angle or reflections on glasses. Closed eyes cannot be detected while your eyes are unreadable.';

  @override
  String get micListening => 'Microphone active (breathing sound detection)';

  @override
  String get micStarting => 'Starting microphone';

  @override
  String get micStopped => 'Microphone input stopped';

  @override
  String get micPermission => 'Check microphone permission';

  @override
  String get deviceSettingsFailed =>
      'Could not change this setting. Open your device settings to change it.';

  @override
  String get beforeUsing => 'Before you start';

  @override
  String get volumeZero =>
      'Alarm volume is zero. Turn it up, then tap “Test sound”.';

  @override
  String get openVolume => 'Open volume settings';

  @override
  String get notificationHint =>
      'Allow notifications to stop an alarm without reopening the app.';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get shortcutHint =>
      'Add a Quick Settings tile to open the app by swiping down from the top of your screen.';

  @override
  String get shortcutAdded => 'Added to Quick Settings';

  @override
  String get addShortcut => 'Add to Quick Settings';

  @override
  String get shortcutManual =>
      'Edit Quick Settings and add “Drowsiness Guard”.';

  @override
  String get sensitivityTitle => 'Detection sensitivity';

  @override
  String get sensitivityStandard => 'Standard';

  @override
  String get sensitivitySensitive => 'Sensitive';

  @override
  String get sensitivityCustom => 'Custom';

  @override
  String get thresholdTitle => 'Seconds before alerting';

  @override
  String get mapsFailed => 'Could not open maps.';

  @override
  String get positionPhone => 'Stand your phone up, facing you.';

  @override
  String get continueWorking =>
      'Monitoring is active. You can continue your task.';

  @override
  String get positionHint =>
      'Keep your face and eyes in view. You can adjust settings later.';

  @override
  String get preparing => 'Getting ready…';

  @override
  String get stopMonitoring => 'Stop monitoring';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get soundFailed =>
      'Could not play the sound. Check your volume settings.';

  @override
  String get testSound => 'Test sound';

  @override
  String get hidePreview => 'Hide preview';

  @override
  String get showPreview => 'Show preview';

  @override
  String get cameraPermission => 'Open camera permissions';

  @override
  String get reconnectCamera => 'Reconnect camera';

  @override
  String get restSafely => 'Stop somewhere safe and rest';

  @override
  String get restSafelyHint =>
      'If you feel drowsy, park somewhere safe and rest. Use maps only after parking.';

  @override
  String get close => 'Close';

  @override
  String get watchOptions => 'Sensitivity and placement';

  @override
  String get car => 'Car';

  @override
  String get desk => 'Desk';

  @override
  String get drivingWarning =>
      'Do not operate the app while driving. It is an aid and cannot guarantee your safety.';

  @override
  String get parkThenMaps => 'Park first, then open maps';

  @override
  String get detectionDetails => 'Detection details';

  @override
  String get falseAlertHint =>
      'Alerted while you were awake? You can adjust sensitivity.';

  @override
  String get adjustSensitivity => 'Adjust sensitivity';

  @override
  String get sensitivityManual =>
      'Sensitivity stays as you set it. Change it only if needed.';

  @override
  String get starting => 'Starting…';

  @override
  String get stop => 'Stop';

  @override
  String get beginDetection => 'Start monitoring';

  @override
  String get navDetect => 'Monitor';

  @override
  String get navNap => 'Nap';

  @override
  String get navHistory => 'History';

  @override
  String get navImprove => 'Habits';

  @override
  String get navSettings => 'Settings';

  @override
  String get notification => 'Notification';

  @override
  String get notificationArrived => 'A notification arrived';

  @override
  String get drowsinessDetection => 'Drowsiness detection';

  @override
  String get napTimer => 'Nap timer';

  @override
  String get raiseHead => '⚠ Wake up! Raise your head';

  @override
  String get openEyes => '⚠ Wake up! Open your eyes';

  @override
  String get breathingAlert => '⚠ Sleep-like breathing detected';

  @override
  String get wakeTime => '⏰ Time to wake up!';

  @override
  String get monitoringStatus => 'Monitoring status';

  @override
  String get restartMic => 'Restart microphone detection';

  @override
  String get returnToResume => 'Return to the app to resume';

  @override
  String get drowsinessSigns => 'Possible signs of drowsiness';

  @override
  String get monitoringMic => 'Monitoring microphone';

  @override
  String get pomodoro => 'Pomodoro';

  @override
  String get currentMode => 'Current mode';

  @override
  String get idle => 'Ready';

  @override
  String get previewHidden => 'Preview hidden. Detection is still running.';

  @override
  String get cameraStartingHint => 'Starting camera…';

  @override
  String get cameraUnavailableHint =>
      'Camera unavailable. Check camera permission.';

  @override
  String get pressStartHint => 'Tap the start button to begin';

  @override
  String get eyesUnknown => 'Eyes —';

  @override
  String get faceMissing => 'No face';

  @override
  String get headTilted => 'Head tilted';

  @override
  String get lookingAway => 'Looking away';

  @override
  String get poseOnlyHint => 'Eyes unreadable. Monitoring posture only';

  @override
  String get checkingEyesPose => 'Checking eyes and posture';

  @override
  String get none => 'None';

  @override
  String get detected => 'Detected';

  @override
  String get stopAlarm => 'Stop';

  @override
  String get illuminating =>
      'Lighting up the screen to find your face.\nNormal brightness returns when your face is detected.';

  @override
  String get awakeStop => 'I’m awake — stop';

  @override
  String get eyesOpenToStop => 'Keep your eyes open for 3 seconds to stop.';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get cameraStarting => 'Starting camera';

  @override
  String get monitoringStopped => 'Monitoring stopped';

  @override
  String get cameraInputStopped => 'Camera input stopped';

  @override
  String get targetFaceMissing => 'Your face is not visible';

  @override
  String get poseOnly => 'Monitoring posture only (eyes unreadable)';

  @override
  String get checkingFaceEyes => 'Checking face and eyes';

  @override
  String get watchingEyesPose => 'Monitoring eyes and posture';

  @override
  String get watchingEyes => 'Monitoring eyes';

  @override
  String get running => 'Running';

  @override
  String get eyesClosedReason => 'Your eyes have stayed closed';

  @override
  String get headTiltReason => 'Your head has stayed tilted. Sit upright';

  @override
  String get breathingReason => 'Regular, sleep-like breathing sounds detected';

  @override
  String get napReason => 'Your nap timer has ended';

  @override
  String get alarmOutputFailed => 'Alarm output failed. Check sound settings.';

  @override
  String get micInputFailed =>
      'Microphone input stopped. Check permission and restart.';

  @override
  String get toneChime => 'Chime';

  @override
  String get toneSiren => 'Siren';

  @override
  String get toneBell => 'Ringing bell';

  @override
  String get possibleDrowsiness => 'Possible signs of drowsiness detected';

  @override
  String get wakeUp => 'Wake up';

  @override
  String get alarmChannel => 'Drowsiness and nap alarms';

  @override
  String get alarmChannelDescription =>
      'Alerts for closed eyes, sleep-like breathing or the end of a nap, with mirroring to compatible watches';

  @override
  String get pomodoroDescription =>
      'Signals when a work or break interval ends';

  @override
  String get hydration => 'Hydration';

  @override
  String get hydrationDescription =>
      'Reminders to drink water at your chosen interval';

  @override
  String get restChannel => 'Rest reminders';

  @override
  String get restChannelDescription =>
      'Reminders to park somewhere safe and rest when drowsiness is detected in car mode';

  @override
  String get watchTestTitle => 'Drowsiness Guard — watch test';

  @override
  String get watchTestBody =>
      'Check whether your watch vibrated. This is a test.';

  @override
  String get takeRest => 'Time to rest';

  @override
  String sensitivityExplanation(int seconds) {
    return 'Alerts after $seconds seconds of closed eyes or a tilted head. Higher sensitivity can trigger alerts during brief movements. PERCLOS and breathing settings stay unchanged.';
  }

  @override
  String optionsSummary(String sensitivity, String placement) {
    return '$sensitivity · $placement';
  }

  @override
  String eyesOpenRemaining(int seconds) {
    return 'Keep your eyes open: ${seconds}s remaining';
  }

  @override
  String napRunning(int minutes) {
    return '$minutes-minute nap in progress';
  }

  @override
  String pomodoroStatus(String phase, String time) {
    return '$phase $time';
  }

  @override
  String eyeReading(String state, String percent) {
    return 'Eyes $state $percent%';
  }

  @override
  String closedDuration(String seconds) {
    return 'Closed ${seconds}s';
  }

  @override
  String nudgeReason(String app) {
    return 'A notification arrived from $app';
  }

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String sliderEndpoint(String value, String label) {
    return '$value ($label)';
  }

  @override
  String get workPhase => 'Working';

  @override
  String get breakPhase => 'On a break';

  @override
  String get eyesClosed => 'closed';

  @override
  String get eyesOpen => 'open';

  @override
  String get lessSensitive => 'Less sensitive';

  @override
  String get restBody => 'Drowsiness detected. Park somewhere safe and rest.';

  @override
  String get restDetails =>
      'Drowsiness detected. Park somewhere safe and rest. After parking, tap to open the app and find nearby parking on a map.';

  @override
  String get termsTitle => 'Before you start';

  @override
  String get termsIntro =>
      'Read the points below, then tap “Agree and start” to use the app.';

  @override
  String get termsAidTitle => 'An aid, with limits';

  @override
  String get termsAidBody =>
      'This app is not a substitute for sleep, a medical device or a safety system.';

  @override
  String get termsMissTitle => 'Alerts can be missed or incorrect';

  @override
  String get termsMissBody =>
      'Darkness, glasses, sunglasses, masks or a face outside the camera view can affect detection. No alert does not mean it is safe to continue.';

  @override
  String get termsDrivingTitle => 'In a vehicle, use only as an aid';

  @override
  String get termsDrivingBody =>
      'You remain responsible for driving safely and following local laws. Do not operate the app while driving. If you feel drowsy, park somewhere safe and rest. We accept no liability for accidents or damage caused by relying on this app.';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get termsPrivacyBody =>
      'Camera and breathing detection run on your device without saving recordings (the only recording is the dashcam you open yourself, saved on this device). In car mode, speed limit alerts (on by default) send the rough area you\'re in, a square about 2 km across, to an OpenStreetMap map server. Optional voice control uses your device’s speech recognition service, which may send audio to its provider. Advertising and purchase services also use network connections.';

  @override
  String get termsAsIsTitle => 'Provided as is';

  @override
  String get termsAsIsBody =>
      'Accuracy and continued availability are not guaranteed. Purchases and refunds follow Google Play’s rules.';

  @override
  String get termsFull => 'Full terms';

  @override
  String get privacyLink => 'Privacy policy (Japanese)';

  @override
  String get agreeStart => 'Agree and start';

  @override
  String get termsRequired => 'You must agree to use the app.';

  @override
  String get voiceStopTitle => 'Stop by voice';

  @override
  String get voiceUnavailable =>
      'Speech recognition is unavailable for this language. Use the on-screen button, volume keys or notification stop button.';

  @override
  String get voiceStopHint =>
      'Say “stop” or “I’m awake” while the alarm is ringing. This uses your device’s speech recognition service, which may send audio to its provider. Unavailable while breathing detection uses the microphone.';

  @override
  String get walkLightTitle => 'Night walk light';

  @override
  String get walkLightBody =>
      'Blinks the rear light twice a second so drivers can spot you. Unlike a reflector, it doesn\'t need their headlights to hit you, so it shows from the side and at angles too. Point the light toward the road and wear the phone in a chest pocket or on a strap. Don\'t walk while looking at the screen.';

  @override
  String get walkLightStart => 'Start blinking';

  @override
  String get walkLightStop => 'Stop blinking';

  @override
  String get walkLightUnsupported => 'This device\'s light isn\'t available.';

  @override
  String get dashcamTitle => 'Dashcam (experimental)';

  @override
  String get dashcamIntro =>
      'Records the road with the rear camera in one-minute clips, keeping the newest 10 (about 10 minutes) and overwriting the oldest. A hard jolt or the Protect button keeps the previous clip and the current one from being overwritten.';

  @override
  String get dashcamOpen => 'Open dashcam';

  @override
  String get dashcamStart => 'Start recording';

  @override
  String get dashcamStop => 'Stop recording';

  @override
  String get dashcamProtect => 'Protect';

  @override
  String get dashcamProtectedNow => 'Protected the clips around this moment';

  @override
  String get dashcamLocked => 'Protected clips';

  @override
  String get dashcamRecent => 'Recent clips (will be overwritten)';

  @override
  String get dashcamEmpty => 'Nothing yet';

  @override
  String get dashcamBusy =>
      'Drowsiness monitoring is using the camera. Only one camera can be open at a time, so stop monitoring before recording.';

  @override
  String get dashcamLimits =>
      'Records only while this screen is open (switching apps stops it). No audio is recorded. Clips stay on this device and leave it only when you share them. There\'s a gap of under a second between clips. This doesn\'t replace a dedicated dashcam.';

  @override
  String get dashcamShare => 'Share / save';

  @override
  String get dashcamDelete => 'Delete';

  @override
  String get speedLimitToggle => 'Speed limit alerts';

  @override
  String get speedLimitHelp =>
      'If you go over the road\'s speed limit for 3 seconds, you\'ll get a short beep and vibration. Limits come from OpenStreetMap, so the rough area you\'re in (a square about 2 km across) is sent to that map server. Your speed, exact position and device identifiers are not sent. Roads without speed-limit data show nothing. Always follow the actual road signs.';

  @override
  String speedLimitNow(String limit) {
    return 'Limit $limit';
  }

  @override
  String speedNow(String speed) {
    return 'Now $speed km/h';
  }

  @override
  String get speedLimitUnknown => 'No speed-limit data';

  @override
  String get speedLimitDenied =>
      'Location permission is off, so speed limits aren\'t available.';

  @override
  String get speedLimitLocationOff => 'Location is turned off on this device.';

  @override
  String get speedLimitNetwork => 'Couldn\'t load map data (no signal?).';

  @override
  String get osmCredit => 'Map data © OpenStreetMap contributors';

  @override
  String get roadForwardCollision => 'Closing in on the car ahead';

  @override
  String get roadTooClose => 'You\'re following too closely';

  @override
  String get roadLeadMoved => 'The car ahead has moved';

  @override
  String get roadCarBehind => 'Car coming up behind you';

  @override
  String get roadSignalRed => 'The light is red';

  @override
  String get roadSignalGo => 'The light is green';

  @override
  String get roadSpeedCamera => 'Speed camera ahead';

  @override
  String get roadOverspeed => 'You\'re over the speed limit';

  @override
  String get dashcamAssist => 'Watch the road ahead';

  @override
  String get dashcamAssistNote =>
      'While recording, it speaks up if you close in fast on the car ahead, follow too closely, when the car ahead moves off at a light, and for speed cameras ahead (only those mapped on OpenStreetMap). Distances are rough, and it misses things at night, in rain, against the light and far away. It never controls the car.';

  @override
  String roadLeadInfo(String meters) {
    return 'Car ahead ~$meters m';
  }

  @override
  String get roadNoLead => 'No car ahead';

  @override
  String get walkModeTitle => 'Walking mode (experimental)';

  @override
  String get walkModeOpen => 'Cars behind you, reading the lights';

  @override
  String get walkBehind => 'Cars behind';

  @override
  String get walkBehindHelp =>
      'Wear the phone facing backward (rear camera pointing behind you) on a bag strap or in a chest pocket. It tells you by voice and vibration when a car is closing in.';

  @override
  String get walkSignal => 'Read the light';

  @override
  String get walkSignalHelp =>
      'Point the rear camera at the traffic light and it says whether it\'s red or green. It can get it wrong, so always check with your own eyes and ears too.';

  @override
  String get walkStart => 'Start watching';

  @override
  String get walkStop => 'Stop';

  @override
  String get signalRedShort => 'Red';

  @override
  String get signalGoShort => 'Green';

  @override
  String get signalUnknownShort => 'Looking for a light';

  @override
  String get emergencyTitle => 'Hard impact detected';

  @override
  String get emergencyBody =>
      'Are you hurt? Call for help if you need it. This screen never calls anyone on its own. The clips from just before and after were protected.';

  @override
  String get emergencyCall119 => 'Call 119 (ambulance/fire, Japan)';

  @override
  String get emergencyCall110 => 'Call 110 (police, Japan)';

  @override
  String get emergencyCallIntl => 'Call emergency 112';

  @override
  String get emergencyShare => 'Send my location';

  @override
  String get emergencyOk => 'I\'m OK (close)';

  @override
  String emergencyShareText(String url) {
    return 'I\'ve been in a crash. My location: $url';
  }

  @override
  String get roadLaneDeparture => 'You\'re drifting out of your lane';

  @override
  String get roadDriverUnresponsive => 'No response';

  @override
  String get unresponsiveTitle => 'No response';

  @override
  String unresponsiveCountdown(String seconds, String number) {
    return 'Calling $number in $seconds s';
  }

  @override
  String get unresponsiveNoContact =>
      'Add a family member\'s number and the app can call them when you don\'t respond (Monitor → Sensitivity and placement).';

  @override
  String get unresponsiveCalled => 'Calling now';

  @override
  String get unresponsiveDialer =>
      'The dialer is open. Tap call to place the call.';

  @override
  String get imAwake => 'I\'m awake (stop)';

  @override
  String get unresponsiveCallToggle =>
      'Call family if you don\'t respond (driver emergency)';

  @override
  String get unresponsiveCallHelp =>
      'In car mode, if the drowsiness alarm keeps ringing for 20 seconds, the app waits 15 more seconds and then calls the number you saved. It never calls emergency services on its own. The number is stored only on this device.';

  @override
  String get emergencyContactLabel => 'Family member\'s phone number';

  @override
  String get laneDepartureToggle => 'Lane departure warning (LDW)';

  @override
  String get laneDepartureHelp =>
      'Above 60 km/h, it tells you when you drift well off your usual position between the lines. It doesn\'t work on faded lines, at night, in rain or on curves. Off by default.';

  @override
  String get carWatchSummary =>
      'In the car it watches for: drowsiness (DDAW), looking away and phone use (ADDW), speed limits (ISA)';

  @override
  String get placementTitle => 'Where you use it';
}
