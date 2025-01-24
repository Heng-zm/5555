import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QRCodeScannerPage(),
    );
  }
}

class QRCodeScannerPage extends StatefulWidget {
  @override
  _QRCodeScannerPageState createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  // Notification Plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Animation State
  Color _scanColor = Colors.transparent;

  // Flashlight State
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    tz.initializeTimeZones();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  // Initialize Notifications
  void _initializeNotifications() {
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    _notificationsPlugin.initialize(initializationSettings);
  }

  // Toggle Flashlight
  void _toggleFlash() async {
    await controller?.toggleFlash();
    bool? isFlashOn = await controller?.getFlashStatus();
    setState(() {
      _isFlashOn = isFlashOn ?? false;
    });
  }

  // Pick Image and Decode QR Code
  void _pickImageAndDecode() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        String? qrData = await QrCodeToolsPlugin.decodeFrom(image.path);
        if (qrData != null) {
          setState(() {
            result = Barcode(qrData, BarcodeFormat.qrcode, []);
            _onScanSuccess();
          });
        } else {
          _onScanError();
          _showErrorDialog('No QR code found in the image.');
        }
      }
    } catch (e) {
      _onScanError();
      _showErrorDialog('Failed to decode QR code from image.');
    }
  }

  // Scan Success Animation
  void _onScanSuccess() {
    setState(() {
      _scanColor = Colors.green.withOpacity(0.5);
    });
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _scanColor = Colors.transparent;
      });
    });
  }

  // Scan Error Animation
  void _onScanError() {
    setState(() {
      _scanColor = Colors.red.withOpacity(0.5);
    });
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _scanColor = Colors.transparent;
      });
    });
  }

  // Show Error Dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Save Notification
  void _notifySaveSuccess() async {
    await _notificationsPlugin.show(
      0,
      'QR Code Saved',
      'Your QR code data has been saved successfully!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'save_channel',
          'Save Notifications',
          channelDescription: 'Notifications for saved QR codes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // Schedule Reminder
  void _scheduleReminder(String message, DateTime scheduledTime) async {
    await _notificationsPlugin.zonedSchedule(
      0,
      'QR Code Reminder',
      message,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          channelDescription: 'QR code reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: false,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  // QR View Created
  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
        _onScanSuccess();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            color: _scanColor,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  (result != null)
                      ? Text(
                          'Data: ${result!.code}',
                          style: const TextStyle(fontSize: 16),
                        )
                      : const Text('Scan a code or upload an image'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickImageAndDecode,
                    child: const Text('Upload QR Code Image'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _scheduleReminder(
                        'Don’t forget to scan your event ticket!',
                        DateTime.now().add(Duration(seconds: 30)),
                      );
                    },
                    child: const Text('Schedule Reminder'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
