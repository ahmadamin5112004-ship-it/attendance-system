import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/attendance_provider.dart';

/// Camera view scanning QR codes and submitting attendance.
class QRScannerScreen extends StatefulWidget {
  final UserModel student;

  const QRScannerScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Processes the captured token, verifies GPS, and displays status overlays.
  Future<void> _processScannedToken(String qrToken) async {
    setState(() => _isProcessing = true);
    _scannerController.stop(); // Stop camera tracking while processing

    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final theme = Theme.of(context);

    // Show processing indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  "Verifying GPS & QR...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Call provider logic
    final bool success = await attendanceProvider.scanAndSubmitAttendance(
      qrToken: qrToken,
      student: widget.student,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog

      if (success) {
        // Success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: Icon(
              Icons.verified_user_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            title: const Text("Verification Successful"),
            content: const Text(
              "Your attendance record has been written to the database.",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context); // Go back to Home Screen
        }
      } else {
        // Error dialog
        final String errorMsg =
            attendanceProvider.errorMessage ?? "Invalid QR code validation.";
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red,
            ),
            title: const Text("Validation Failed"),
            content: Text(errorMsg, textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  setState(() => _isProcessing = false);
                  _scannerController.start(); // Restart camera
                },
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Scanner",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Torch Toggle Button
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(
                      Icons.flash_off_rounded,
                      color: Colors.white,
                    );
                  case TorchState.on:
                    return const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.amber,
                    );
                  default:
                    return const Icon(
                      Icons.flash_off_rounded,
                      color: Colors.white30,
                    );
                }
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // The camera scanner widget
          MobileScanner(
            controller: _scannerController,
            onDetect: (BarcodeCapture capture) {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  _processScannedToken(code);
                }
              }
            },
          ),

          // Scanning Overlay Frame Graphic
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Outer border ring for visual centering
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 3.5,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Stack(
                        children: [
                          // Subtle glass overlay inside reticle
                          Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: const Text(
                        "Align Attendance QR inside the box",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
