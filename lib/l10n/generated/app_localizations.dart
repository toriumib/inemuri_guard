import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness Guard'**
  String get appName;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get setupTitle;

  /// No description provided for @setupReady.
  ///
  /// In en, this message translates to:
  /// **'Your face and eyes are visible. Now check the sound.'**
  String get setupReady;

  /// No description provided for @setupSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Tap “Start monitoring” below and allow the camera.\n2. Position your phone so your face and eyes are visible.\n3. Check the sound.'**
  String get setupSteps;

  /// No description provided for @soundOutputFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play the sound. Check the volume and audio output.'**
  String get soundOutputFailed;

  /// No description provided for @checkSound.
  ///
  /// In en, this message translates to:
  /// **'Check the sound'**
  String get checkSound;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get saveFailed;

  /// No description provided for @setupComplete.
  ///
  /// In en, this message translates to:
  /// **'I heard it — finish setup'**
  String get setupComplete;

  /// No description provided for @dismissForNow.
  ///
  /// In en, this message translates to:
  /// **'Dismiss for now'**
  String get dismissForNow;

  /// No description provided for @setupHint.
  ///
  /// In en, this message translates to:
  /// **'Next time, you can start with your saved settings. You can set up notifications and watch alerts later in Settings.'**
  String get setupHint;

  /// No description provided for @cameraRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Reconnect camera” below. Close any other app that is using the camera.'**
  String get cameraRecoveryHint;

  /// No description provided for @faceRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Keep only your face in view and improve the lighting. Restart monitoring when a different person uses the app.'**
  String get faceRecoveryHint;

  /// No description provided for @eyeRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust your angle or reflections on glasses. Closed eyes cannot be detected while your eyes are unreadable.'**
  String get eyeRecoveryHint;

  /// No description provided for @micListening.
  ///
  /// In en, this message translates to:
  /// **'Microphone active (breathing sound detection)'**
  String get micListening;

  /// No description provided for @micStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting microphone'**
  String get micStarting;

  /// No description provided for @micStopped.
  ///
  /// In en, this message translates to:
  /// **'Microphone input stopped'**
  String get micStopped;

  /// No description provided for @micPermission.
  ///
  /// In en, this message translates to:
  /// **'Check microphone permission'**
  String get micPermission;

  /// No description provided for @deviceSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change this setting. Open your device settings to change it.'**
  String get deviceSettingsFailed;

  /// No description provided for @beforeUsing.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get beforeUsing;

  /// No description provided for @volumeZero.
  ///
  /// In en, this message translates to:
  /// **'Alarm volume is zero. Turn it up, then tap “Test sound”.'**
  String get volumeZero;

  /// No description provided for @openVolume.
  ///
  /// In en, this message translates to:
  /// **'Open volume settings'**
  String get openVolume;

  /// No description provided for @notificationHint.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to stop an alarm without reopening the app.'**
  String get notificationHint;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @shortcutHint.
  ///
  /// In en, this message translates to:
  /// **'Add a Quick Settings tile to open the app by swiping down from the top of your screen.'**
  String get shortcutHint;

  /// No description provided for @shortcutAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to Quick Settings'**
  String get shortcutAdded;

  /// No description provided for @addShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add to Quick Settings'**
  String get addShortcut;

  /// No description provided for @shortcutManual.
  ///
  /// In en, this message translates to:
  /// **'Edit Quick Settings and add “Drowsiness Guard”.'**
  String get shortcutManual;

  /// No description provided for @sensitivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Detection sensitivity'**
  String get sensitivityTitle;

  /// No description provided for @sensitivityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get sensitivityStandard;

  /// No description provided for @sensitivitySensitive.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get sensitivitySensitive;

  /// No description provided for @sensitivityCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sensitivityCustom;

  /// No description provided for @thresholdTitle.
  ///
  /// In en, this message translates to:
  /// **'Seconds before alerting'**
  String get thresholdTitle;

  /// No description provided for @mapsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps.'**
  String get mapsFailed;

  /// No description provided for @positionPhone.
  ///
  /// In en, this message translates to:
  /// **'Stand your phone up, facing you.'**
  String get positionPhone;

  /// No description provided for @continueWorking.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is active. You can continue your task.'**
  String get continueWorking;

  /// No description provided for @positionHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your face and eyes in view. You can adjust settings later.'**
  String get positionHint;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get preparing;

  /// No description provided for @stopMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Stop monitoring'**
  String get stopMonitoring;

  /// No description provided for @startMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring'**
  String get startMonitoring;

  /// No description provided for @soundFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play the sound. Check your volume settings.'**
  String get soundFailed;

  /// No description provided for @testSound.
  ///
  /// In en, this message translates to:
  /// **'Test sound'**
  String get testSound;

  /// No description provided for @hidePreview.
  ///
  /// In en, this message translates to:
  /// **'Hide preview'**
  String get hidePreview;

  /// No description provided for @showPreview.
  ///
  /// In en, this message translates to:
  /// **'Show preview'**
  String get showPreview;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Open camera permissions'**
  String get cameraPermission;

  /// No description provided for @reconnectCamera.
  ///
  /// In en, this message translates to:
  /// **'Reconnect camera'**
  String get reconnectCamera;

  /// No description provided for @restSafely.
  ///
  /// In en, this message translates to:
  /// **'Stop somewhere safe and rest'**
  String get restSafely;

  /// No description provided for @restSafelyHint.
  ///
  /// In en, this message translates to:
  /// **'If you feel drowsy, park somewhere safe and rest. Use maps only after parking.'**
  String get restSafelyHint;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @watchOptions.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity and placement'**
  String get watchOptions;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @desk.
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get desk;

  /// No description provided for @drivingWarning.
  ///
  /// In en, this message translates to:
  /// **'Do not operate the app while driving. It is an aid and cannot guarantee your safety.'**
  String get drivingWarning;

  /// No description provided for @parkThenMaps.
  ///
  /// In en, this message translates to:
  /// **'Park first, then open maps'**
  String get parkThenMaps;

  /// No description provided for @detectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Detection details'**
  String get detectionDetails;

  /// No description provided for @falseAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Alerted while you were awake? You can adjust sensitivity.'**
  String get falseAlertHint;

  /// No description provided for @adjustSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Adjust sensitivity'**
  String get adjustSensitivity;

  /// No description provided for @sensitivityManual.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity stays as you set it. Change it only if needed.'**
  String get sensitivityManual;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get starting;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @beginDetection.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring'**
  String get beginDetection;

  /// No description provided for @navDetect.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get navDetect;

  /// No description provided for @navNap.
  ///
  /// In en, this message translates to:
  /// **'Nap'**
  String get navNap;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navImprove.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get navImprove;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @notificationArrived.
  ///
  /// In en, this message translates to:
  /// **'A notification arrived'**
  String get notificationArrived;

  /// No description provided for @drowsinessDetection.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness detection'**
  String get drowsinessDetection;

  /// No description provided for @napTimer.
  ///
  /// In en, this message translates to:
  /// **'Nap timer'**
  String get napTimer;

  /// No description provided for @raiseHead.
  ///
  /// In en, this message translates to:
  /// **'⚠ Wake up! Raise your head'**
  String get raiseHead;

  /// No description provided for @openEyes.
  ///
  /// In en, this message translates to:
  /// **'⚠ Wake up! Open your eyes'**
  String get openEyes;

  /// No description provided for @breathingAlert.
  ///
  /// In en, this message translates to:
  /// **'⚠ Sleep-like breathing detected'**
  String get breathingAlert;

  /// No description provided for @wakeTime.
  ///
  /// In en, this message translates to:
  /// **'⏰ Time to wake up!'**
  String get wakeTime;

  /// No description provided for @monitoringStatus.
  ///
  /// In en, this message translates to:
  /// **'Monitoring status'**
  String get monitoringStatus;

  /// No description provided for @restartMic.
  ///
  /// In en, this message translates to:
  /// **'Restart microphone detection'**
  String get restartMic;

  /// No description provided for @returnToResume.
  ///
  /// In en, this message translates to:
  /// **'Return to the app to resume'**
  String get returnToResume;

  /// No description provided for @drowsinessSigns.
  ///
  /// In en, this message translates to:
  /// **'Possible signs of drowsiness'**
  String get drowsinessSigns;

  /// No description provided for @monitoringMic.
  ///
  /// In en, this message translates to:
  /// **'Monitoring microphone'**
  String get monitoringMic;

  /// No description provided for @pomodoro.
  ///
  /// In en, this message translates to:
  /// **'Pomodoro'**
  String get pomodoro;

  /// No description provided for @currentMode.
  ///
  /// In en, this message translates to:
  /// **'Current mode'**
  String get currentMode;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get idle;

  /// No description provided for @previewHidden.
  ///
  /// In en, this message translates to:
  /// **'Preview hidden. Detection is still running.'**
  String get previewHidden;

  /// No description provided for @cameraStartingHint.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get cameraStartingHint;

  /// No description provided for @cameraUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check camera permission.'**
  String get cameraUnavailableHint;

  /// No description provided for @pressStartHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the start button to begin'**
  String get pressStartHint;

  /// No description provided for @eyesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Eyes —'**
  String get eyesUnknown;

  /// No description provided for @faceMissing.
  ///
  /// In en, this message translates to:
  /// **'No face'**
  String get faceMissing;

  /// No description provided for @headTilted.
  ///
  /// In en, this message translates to:
  /// **'Head tilted'**
  String get headTilted;

  /// No description provided for @lookingAway.
  ///
  /// In en, this message translates to:
  /// **'Looking away'**
  String get lookingAway;

  /// No description provided for @poseOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Eyes unreadable. Monitoring posture only'**
  String get poseOnlyHint;

  /// No description provided for @checkingEyesPose.
  ///
  /// In en, this message translates to:
  /// **'Checking eyes and posture'**
  String get checkingEyesPose;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @detected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// No description provided for @stopAlarm.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopAlarm;

  /// No description provided for @illuminating.
  ///
  /// In en, this message translates to:
  /// **'Lighting up the screen to find your face.\nNormal brightness returns when your face is detected.'**
  String get illuminating;

  /// No description provided for @awakeStop.
  ///
  /// In en, this message translates to:
  /// **'I’m awake — stop'**
  String get awakeStop;

  /// No description provided for @eyesOpenToStop.
  ///
  /// In en, this message translates to:
  /// **'Keep your eyes open for 3 seconds to stop.'**
  String get eyesOpenToStop;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailable;

  /// No description provided for @cameraStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting camera'**
  String get cameraStarting;

  /// No description provided for @monitoringStopped.
  ///
  /// In en, this message translates to:
  /// **'Monitoring stopped'**
  String get monitoringStopped;

  /// No description provided for @cameraInputStopped.
  ///
  /// In en, this message translates to:
  /// **'Camera input stopped'**
  String get cameraInputStopped;

  /// No description provided for @targetFaceMissing.
  ///
  /// In en, this message translates to:
  /// **'Your face is not visible'**
  String get targetFaceMissing;

  /// No description provided for @poseOnly.
  ///
  /// In en, this message translates to:
  /// **'Monitoring posture only (eyes unreadable)'**
  String get poseOnly;

  /// No description provided for @checkingFaceEyes.
  ///
  /// In en, this message translates to:
  /// **'Checking face and eyes'**
  String get checkingFaceEyes;

  /// No description provided for @watchingEyesPose.
  ///
  /// In en, this message translates to:
  /// **'Monitoring eyes and posture'**
  String get watchingEyesPose;

  /// No description provided for @watchingEyes.
  ///
  /// In en, this message translates to:
  /// **'Monitoring eyes'**
  String get watchingEyes;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @eyesClosedReason.
  ///
  /// In en, this message translates to:
  /// **'Your eyes have stayed closed'**
  String get eyesClosedReason;

  /// No description provided for @headTiltReason.
  ///
  /// In en, this message translates to:
  /// **'Your head has stayed tilted. Sit upright'**
  String get headTiltReason;

  /// No description provided for @breathingReason.
  ///
  /// In en, this message translates to:
  /// **'Regular, sleep-like breathing sounds detected'**
  String get breathingReason;

  /// No description provided for @napReason.
  ///
  /// In en, this message translates to:
  /// **'Your nap timer has ended'**
  String get napReason;

  /// No description provided for @alarmOutputFailed.
  ///
  /// In en, this message translates to:
  /// **'Alarm output failed. Check sound settings.'**
  String get alarmOutputFailed;

  /// No description provided for @micInputFailed.
  ///
  /// In en, this message translates to:
  /// **'Microphone input stopped. Check permission and restart.'**
  String get micInputFailed;

  /// No description provided for @toneChime.
  ///
  /// In en, this message translates to:
  /// **'Chime'**
  String get toneChime;

  /// No description provided for @toneSiren.
  ///
  /// In en, this message translates to:
  /// **'Siren'**
  String get toneSiren;

  /// No description provided for @toneBell.
  ///
  /// In en, this message translates to:
  /// **'Ringing bell'**
  String get toneBell;

  /// No description provided for @possibleDrowsiness.
  ///
  /// In en, this message translates to:
  /// **'Possible signs of drowsiness detected'**
  String get possibleDrowsiness;

  /// No description provided for @wakeUp.
  ///
  /// In en, this message translates to:
  /// **'Wake up'**
  String get wakeUp;

  /// No description provided for @alarmChannel.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness and nap alarms'**
  String get alarmChannel;

  /// No description provided for @alarmChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts for closed eyes, sleep-like breathing or the end of a nap, with mirroring to compatible watches'**
  String get alarmChannelDescription;

  /// No description provided for @pomodoroDescription.
  ///
  /// In en, this message translates to:
  /// **'Signals when a work or break interval ends'**
  String get pomodoroDescription;

  /// No description provided for @hydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get hydration;

  /// No description provided for @hydrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders to drink water at your chosen interval'**
  String get hydrationDescription;

  /// No description provided for @restChannel.
  ///
  /// In en, this message translates to:
  /// **'Rest reminders'**
  String get restChannel;

  /// No description provided for @restChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders to park somewhere safe and rest when drowsiness is detected in car mode'**
  String get restChannelDescription;

  /// No description provided for @watchTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness Guard — watch test'**
  String get watchTestTitle;

  /// No description provided for @watchTestBody.
  ///
  /// In en, this message translates to:
  /// **'Check whether your watch vibrated. This is a test.'**
  String get watchTestBody;

  /// No description provided for @takeRest.
  ///
  /// In en, this message translates to:
  /// **'Time to rest'**
  String get takeRest;

  /// No description provided for @sensitivityExplanation.
  ///
  /// In en, this message translates to:
  /// **'Alerts after {seconds} seconds of closed eyes or a tilted head. Higher sensitivity can trigger alerts during brief movements. PERCLOS and breathing settings stay unchanged.'**
  String sensitivityExplanation(int seconds);

  /// No description provided for @optionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{sensitivity} · {placement}'**
  String optionsSummary(String sensitivity, String placement);

  /// No description provided for @eyesOpenRemaining.
  ///
  /// In en, this message translates to:
  /// **'Keep your eyes open: {seconds}s remaining'**
  String eyesOpenRemaining(int seconds);

  /// No description provided for @napRunning.
  ///
  /// In en, this message translates to:
  /// **'{minutes}-minute nap in progress'**
  String napRunning(int minutes);

  /// No description provided for @pomodoroStatus.
  ///
  /// In en, this message translates to:
  /// **'{phase} {time}'**
  String pomodoroStatus(String phase, String time);

  /// No description provided for @eyeReading.
  ///
  /// In en, this message translates to:
  /// **'Eyes {state} {percent}%'**
  String eyeReading(String state, String percent);

  /// No description provided for @closedDuration.
  ///
  /// In en, this message translates to:
  /// **'Closed {seconds}s'**
  String closedDuration(String seconds);

  /// No description provided for @nudgeReason.
  ///
  /// In en, this message translates to:
  /// **'A notification arrived from {app}'**
  String nudgeReason(String app);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSeconds(int seconds);

  /// No description provided for @sliderEndpoint.
  ///
  /// In en, this message translates to:
  /// **'{value} ({label})'**
  String sliderEndpoint(String value, String label);

  /// No description provided for @workPhase.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get workPhase;

  /// No description provided for @breakPhase.
  ///
  /// In en, this message translates to:
  /// **'On a break'**
  String get breakPhase;

  /// No description provided for @eyesClosed.
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get eyesClosed;

  /// No description provided for @eyesOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get eyesOpen;

  /// No description provided for @lessSensitive.
  ///
  /// In en, this message translates to:
  /// **'Less sensitive'**
  String get lessSensitive;

  /// No description provided for @restBody.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness detected. Park somewhere safe and rest.'**
  String get restBody;

  /// No description provided for @restDetails.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness detected. Park somewhere safe and rest. After parking, tap to open the app and find nearby parking on a map.'**
  String get restDetails;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get termsTitle;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'Read the points below, then tap “Agree and start” to use the app.'**
  String get termsIntro;

  /// No description provided for @termsAidTitle.
  ///
  /// In en, this message translates to:
  /// **'An aid, with limits'**
  String get termsAidTitle;

  /// No description provided for @termsAidBody.
  ///
  /// In en, this message translates to:
  /// **'This app is not a substitute for sleep, a medical device or a safety system.'**
  String get termsAidBody;

  /// No description provided for @termsMissTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts can be missed or incorrect'**
  String get termsMissTitle;

  /// No description provided for @termsMissBody.
  ///
  /// In en, this message translates to:
  /// **'Darkness, glasses, sunglasses, masks or a face outside the camera view can affect detection. No alert does not mean it is safe to continue.'**
  String get termsMissBody;

  /// No description provided for @termsDrivingTitle.
  ///
  /// In en, this message translates to:
  /// **'In a vehicle, use only as an aid'**
  String get termsDrivingTitle;

  /// No description provided for @termsDrivingBody.
  ///
  /// In en, this message translates to:
  /// **'You remain responsible for driving safely and following local laws. Do not operate the app while driving. If you feel drowsy, park somewhere safe and rest. We accept no liability for accidents or damage caused by relying on this app.'**
  String get termsDrivingBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @termsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Camera and breathing detection run on your device without saving recordings (the only recording is the dashcam you open yourself, saved on this device). In car mode, speed limit alerts (on by default) send the rough area you\'re in, a square about 2 km across, to an OpenStreetMap map server. Optional voice control uses your device’s speech recognition service, which may send audio to its provider. Advertising and purchase services also use network connections.'**
  String get termsPrivacyBody;

  /// No description provided for @termsAsIsTitle.
  ///
  /// In en, this message translates to:
  /// **'Provided as is'**
  String get termsAsIsTitle;

  /// No description provided for @termsAsIsBody.
  ///
  /// In en, this message translates to:
  /// **'Accuracy and continued availability are not guaranteed. Purchases and refunds follow Google Play’s rules.'**
  String get termsAsIsBody;

  /// No description provided for @termsFull.
  ///
  /// In en, this message translates to:
  /// **'Full terms'**
  String get termsFull;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy (Japanese)'**
  String get privacyLink;

  /// No description provided for @agreeStart.
  ///
  /// In en, this message translates to:
  /// **'Agree and start'**
  String get agreeStart;

  /// No description provided for @termsRequired.
  ///
  /// In en, this message translates to:
  /// **'You must agree to use the app.'**
  String get termsRequired;

  /// No description provided for @voiceStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop by voice'**
  String get voiceStopTitle;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is unavailable for this language. Use the on-screen button, volume keys or notification stop button.'**
  String get voiceUnavailable;

  /// No description provided for @voiceStopHint.
  ///
  /// In en, this message translates to:
  /// **'Say “stop” or “I’m awake” while the alarm is ringing. This uses your device’s speech recognition service, which may send audio to its provider. Unavailable while breathing detection uses the microphone.'**
  String get voiceStopHint;

  /// No description provided for @walkLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Night walk light'**
  String get walkLightTitle;

  /// No description provided for @walkLightBody.
  ///
  /// In en, this message translates to:
  /// **'Blinks the rear light twice a second so drivers can spot you. Unlike a reflector, it doesn\'t need their headlights to hit you, so it shows from the side and at angles too. Point the light toward the road and wear the phone in a chest pocket or on a strap. Don\'t walk while looking at the screen.'**
  String get walkLightBody;

  /// No description provided for @walkLightStart.
  ///
  /// In en, this message translates to:
  /// **'Start blinking'**
  String get walkLightStart;

  /// No description provided for @walkLightStop.
  ///
  /// In en, this message translates to:
  /// **'Stop blinking'**
  String get walkLightStop;

  /// No description provided for @walkLightUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device\'s light isn\'t available.'**
  String get walkLightUnsupported;

  /// No description provided for @dashcamTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashcam (experimental)'**
  String get dashcamTitle;

  /// No description provided for @dashcamIntro.
  ///
  /// In en, this message translates to:
  /// **'Records the road with the rear camera in one-minute clips, keeping the newest 10 (about 10 minutes) and overwriting the oldest. A hard jolt or the Protect button keeps the previous clip and the current one from being overwritten.'**
  String get dashcamIntro;

  /// No description provided for @dashcamOpen.
  ///
  /// In en, this message translates to:
  /// **'Open dashcam'**
  String get dashcamOpen;

  /// No description provided for @dashcamStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get dashcamStart;

  /// No description provided for @dashcamStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get dashcamStop;

  /// No description provided for @dashcamProtect.
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get dashcamProtect;

  /// No description provided for @dashcamProtectedNow.
  ///
  /// In en, this message translates to:
  /// **'Protected the clips around this moment'**
  String get dashcamProtectedNow;

  /// No description provided for @dashcamLocked.
  ///
  /// In en, this message translates to:
  /// **'Protected clips'**
  String get dashcamLocked;

  /// No description provided for @dashcamRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent clips (will be overwritten)'**
  String get dashcamRecent;

  /// No description provided for @dashcamEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get dashcamEmpty;

  /// No description provided for @dashcamBusy.
  ///
  /// In en, this message translates to:
  /// **'Drowsiness monitoring is using the camera. Only one camera can be open at a time, so stop monitoring before recording.'**
  String get dashcamBusy;

  /// No description provided for @dashcamLimits.
  ///
  /// In en, this message translates to:
  /// **'Records only while this screen is open (switching apps stops it). No audio is recorded. Clips stay on this device and leave it only when you share them. There\'s a gap of under a second between clips. This doesn\'t replace a dedicated dashcam.'**
  String get dashcamLimits;

  /// No description provided for @dashcamShare.
  ///
  /// In en, this message translates to:
  /// **'Share / save'**
  String get dashcamShare;

  /// No description provided for @dashcamDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dashcamDelete;

  /// No description provided for @speedLimitToggle.
  ///
  /// In en, this message translates to:
  /// **'Speed limit alerts'**
  String get speedLimitToggle;

  /// No description provided for @speedLimitHelp.
  ///
  /// In en, this message translates to:
  /// **'If you go over the road\'s speed limit for 3 seconds, you\'ll get a short beep and vibration. Limits come from OpenStreetMap, so the rough area you\'re in (a square about 2 km across) is sent to that map server. Your speed, exact position and device identifiers are not sent. Roads without speed-limit data show nothing. Always follow the actual road signs.'**
  String get speedLimitHelp;

  /// No description provided for @speedLimitNow.
  ///
  /// In en, this message translates to:
  /// **'Limit {limit}'**
  String speedLimitNow(String limit);

  /// No description provided for @speedNow.
  ///
  /// In en, this message translates to:
  /// **'Now {speed} km/h'**
  String speedNow(String speed);

  /// No description provided for @speedLimitUnknown.
  ///
  /// In en, this message translates to:
  /// **'No speed-limit data'**
  String get speedLimitUnknown;

  /// No description provided for @speedLimitDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off, so speed limits aren\'t available.'**
  String get speedLimitDenied;

  /// No description provided for @speedLimitLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this device.'**
  String get speedLimitLocationOff;

  /// No description provided for @speedLimitNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load map data (no signal?).'**
  String get speedLimitNetwork;

  /// No description provided for @osmCredit.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors'**
  String get osmCredit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
