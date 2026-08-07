import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/info_card.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import 'history_screen.dart';

/// The main dashboard screen visible to authenticated students.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCreatingDemo = false;

  /// Handles student sign out.
  void _handleLogout(BuildContext context) {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  /// Helper to request GPS coordinates and write a mock session to Firestore.
  /// Sets coordinates exactly matching the student's current position so they can pass distance checks.
  Future<void> _handleCreateDemoSession(BuildContext context) async {
    setState(() => _isCreatingDemo = true);
    final theme = Theme.of(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    try {
      // 1. Verify location permissions and get current coordinates
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw "GPS location permission is required to create a session at your current coordinates.";
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 2. Write mock session document to Firestore
      const String qrToken = "SE_TEST_TOKEN_2026";
      const String courseName = "Software Engineering CS-402";

      final sessionId = await attendanceProvider.createDebugSession(
        qrToken: qrToken,
        latitude: position.latitude,
        longitude: position.longitude,
        courseName: courseName,
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text("Demo Session Active"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "A session has been successfully added to Firestore!",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text("• Document ID: $sessionId"),
                Text("• Course Name: $courseName"),
                Text("• QR Token: $qrToken"),
                Text("• Latitude: ${position.latitude.toStringAsFixed(6)}"),
                Text("• Longitude: ${position.longitude.toStringAsFixed(6)}"),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Emulator Support:\nIf testing on an emulator without a camera/QR code, use the simulator shortcut on the dashboard to test submission immediately.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Error Creating Session"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingDemo = false);
      }
    }
  }

  /// Triggers a simulated scanning verification to bypass camera controls during testing.
  Future<void> _handleSimulateScan(BuildContext context) async {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Simulating QR verify & GPS check..."),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await attendanceProvider.scanAndSubmitAttendance(
      qrToken: "SE_TEST_TOKEN_2026",
      student: authProvider.currentUser!,
    );

    if (context.mounted) {
      Navigator.pop(context); // Dismiss loading dialog

      if (success) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: Icon(
              Icons.verified_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            title: const Text("Attendance Marked"),
            content: const Text(
              "Congratulations! Your attendance has been successfully validated and logged.",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Awesome"),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red,
            ),
            title: const Text("Submission Failed"),
            content: Text(
              attendanceProvider.errorMessage ??
                  "An unknown validation error occurred.",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Try Again"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final student = authProvider.currentUser;

    if (student == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Terminal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Text(
                "Welcome back,",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                student.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Student Data Information Panel
              InfoCard(
                icon: Icons.person_outline_rounded,
                title: "Student Account Name",
                value: student.name,
              ),
              const SizedBox(height: 12),
              InfoCard(
                icon: Icons.badge_outlined,
                title: "Academic Student ID",
                value: student.studentId,
              ),
              const SizedBox(height: 32),

              // Main Project Features - Scan Button
              CustomButton(
                text: "Scan Attendance QR",
                icon: Icons.qr_code_scanner_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QRScannerScreen(student: student),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // View Attendance History
              CustomButton(
                text: "Attendance History Logs",
                icon: Icons.history_rounded,
                isGradient: false,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(student: student),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Developer Testing Area
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Grading / Developer Controls",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Use these helpers to test QR detection and distance geofencing validation without setting up separate admin/scanner environments.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step 1: Create active session
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isCreatingDemo
                          ? null
                          : () => _handleCreateDemoSession(context),
                      icon: _isCreatingDemo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_location_alt_rounded),
                      label: const Text(
                        "1. Seed Test Session at Current Location",
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step 2: Simulate Scan
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.secondary.withOpacity(0.5),
                        ),
                      ),
                      onPressed: () => _handleSimulateScan(context),
                      icon: const Icon(Icons.animation_rounded),
                      label: const Text("2. Simulate Scanning Test QR"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
