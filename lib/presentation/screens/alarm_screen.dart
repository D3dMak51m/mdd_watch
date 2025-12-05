import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vibration/vibration.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  int _seconds = 30;
  StreamSubscription? _timerSubscription;

  @override
  void initState() {
    super.initState();

    // Слушаем тики таймера из сервиса
    _timerSubscription = FlutterBackgroundService().on('timerTick').listen((event) {
      if (event != null) {
        setState(() {
          _seconds = event['seconds'];
        });
        if (_seconds <= 0) {
          // Таймер истек, экран можно закрыть или показать "Sent"
          // Navigator.pop(context);
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("SOS Sent! Waiting for help...")),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }

  void _cancelHelp() {
    FlutterBackgroundService().invoke('cancelSos');
    Vibration.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
            // const SizedBox(height: 20),
            // const Text(
            //   "FALL DETECTED",
            //   style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 10),
            const Text(
              "Sending alert in",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              "$_seconds",
              style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                  ),
                  onPressed: _cancelHelp,
                  child: const Text("I AM OK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}