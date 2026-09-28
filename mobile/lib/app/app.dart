import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/protection_provider.dart';
import '../providers/pulse_provider.dart';
import '../services/alert_service.dart';
import '../services/gesture/gesture_detection_service.dart';
import '../services/sms_service.dart';
import '../screens/splash_screen.dart';
import 'theme.dart';

class VigilanceApp extends StatelessWidget {
  const VigilanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Single GestureDetectionService instance shared by PulseProvider
    // (setup/test) and ProtectionProvider (live monitoring) — recording,
    // testing, and live detection must use one consistent detector/config.
    final gestureService = GestureDetectionService();

    // MOCK/DEVELOPMENT ONLY — see services/sms_service.dart. Swap for
    // RealSmsService once on-device SMS sending has been tested on real
    // hardware, or for a networked provider-backed implementation once
    // SMS_API_KEY/SECRET/SENDER are supplied (docs/ARCHITECTURE.md §8).
    final smsService = MockSmsService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(
          create: (_) => PulseProvider(detectionService: gestureService)..loadSaved(),
        ),
        ChangeNotifierProvider(create: (_) => ProtectionProvider(detectionService: gestureService)),
        ChangeNotifierProvider(
          create: (_) => EmergencyProvider(alertService: AlertService(sms: smsService)),
        ),
      ],
      child: MaterialApp(
        title: 'VIGILANCE',
        debugShowCheckedModeBanner: false,
        theme: VigilanceTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
