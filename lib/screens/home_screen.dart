import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session.dart';
import '../services/beacon_service.dart';
import '../services/notification_service.dart';
import 'checkin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String _matric = '';

  @override
  void initState() {
    super.initState();
    _loadMatric();
    final notif = NotificationService();
    notif.init();
    // listen to beacon changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final beacon = Provider.of<BeaconService>(context, listen: false);
      beacon.addListener(_onBeaconChange);
      // Start real beacon scanning
      beacon.startScanning();
    });
  }

  Future<void> _loadMatric() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _matric = prefs.getString('matric') ?? '';
    });
  }

  void _onBeaconChange() {
    final beacon = Provider.of<BeaconService>(context, listen: false);
    if (beacon.isInside) {
      print('[DEBUG] Enter detected, starting session and welcome flow');
      _startSession();
      _showWelcomeFlow();
    } else {
      print('[DEBUG] Exit detected, ending session and exit flow');
      _endSession();
      _showExitFlow();
    }
  }

  void _startSession() {
    _ticker?.cancel();
    setState(() {
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _endSession() async {
    _ticker?.cancel();
    if (_matric.isNotEmpty) {
      final now = DateTime.now();
      final session = Session(matric: _matric, start: now.subtract(_elapsed), end: now);
      // Save session to Firestore
      await FirebaseFirestore.instance.collection('sessions').add({
        'matric': session.matric,
        'start': session.start.toIso8601String(),
        'end': session.end.toIso8601String(),
        'duration_seconds': session.duration.inSeconds,
      });
    }
    setState(() {
      _elapsed = Duration.zero;
    });
  }

  Future<void> _showWelcomeFlow() async {
    final notif = NotificationService();
    await notif.showNotification(title: 'Welcome to Perpustakaan Tun Abdul Razak UiTM', body: 'Please switch your phone to silent.');
    _showRulesIfNeeded();
  }

  Future<void> _showExitFlow() async {
  print('[DEBUG] Showing exit notification');
  final notif = NotificationService();
  await notif.showNotification(title: 'Thank you', body: 'Thanks for visiting the library.');
  }

  Future<void> _showRulesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hide = prefs.getBool('hide_rules') ?? false;
    if (!hide) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Library Rules'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• No food allowed'),
              Text('• Plese keep quiet'),
              Text('• Put your phone on silent'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('hide_rules', true);
                Navigator.of(context).pop();
              },
              child: const Text("Don't show again"),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final beacon = Provider.of<BeaconService>(context, listen: false);
    beacon.removeListener(_onBeaconChange);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final beacon = Provider.of<BeaconService>(context);
    final status = beacon.isInside ? 'Inside' : 'Outside';
    final now = DateFormat.jm().format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('PTAR UiTM Jasin'),
        backgroundColor: Colors.blueGrey,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            beacon.isInside ? Icons.meeting_room : Icons.exit_to_app,
                            color: beacon.isInside ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text('Status: $status', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Time: $now'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (beacon.isInside) ...[
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text('Session: ${_formatDuration(_elapsed)}', style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Matric: ${_matric.isEmpty ? 'Not checked in' : _matric}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Check-in / Profile'),
                      onPressed: () async {
                        final r = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckinScreen()));
                        if (r == true) _loadMatric();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Simulate Enter/Exit'),
                      onPressed: () async {
                        final b = Provider.of<BeaconService>(context, listen: false);
                        b.toggleMock();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.rule),
                            label: const Text('Show Rules'),
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('hide_rules', false);
                              _showRulesIfNeeded();
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Send Silent Reminder'),
                            onPressed: () async {
                              final notif = NotificationService();
                              await notif.showNotification(title: 'Silent Reminder', body: 'Please switch to silent mode');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
