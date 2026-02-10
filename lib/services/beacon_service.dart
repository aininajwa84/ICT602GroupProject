
import 'package:flutter/foundation.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

/// Mock beacon service. Replace with real BLE/region monitoring implementation later.
class BeaconService extends ChangeNotifier {
  Stream<RangingResult>? _stream;
  StreamSubscription<RangingResult>? _subscription;
  bool _scanning = false;
  // Provided beacon identifiers (from user)
  static const String beaconUuid = 'fda50693-a4e2-4fb1-afcf-c6eb07647825';
  static const String beaconMac = 'C6:21:45:45:15:71';
  static const int beaconMajor = 10011;
  static const int beaconMinor = 19641;

  bool _isInside = false;
  bool get isInside => _isInside;

  DateTime? lastEnter;
  DateTime? lastExit;

  /// Start scanning for the configured beacon. Call this from your app init.
  Future<void> startScanning() async {
    if (_scanning) return;
    // Request permissions
    await _ensurePermissions();
    await flutterBeacon.initializeScanning;
    final region = Region(
      identifier: 'library',
      proximityUUID: beaconUuid,
      major: beaconMajor,
      minor: beaconMinor,
    );
    _stream = flutterBeacon.ranging([region]);
    _subscription = _stream!.listen(_onRangingResult, onError: (e) {
      // ignore: avoid_print
      print('Beacon scan error: $e');
    });
    _scanning = true;
  }

  void stopScanning() {
    _subscription?.cancel();
    _subscription = null;
    _scanning = false;
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();
  }

  void _onRangingResult(RangingResult result) {
    final beacons = result.beacons;
    final found = beacons.any((b) =>
      b.proximityUUID.toLowerCase() == beaconUuid.toLowerCase() &&
      b.major == beaconMajor &&
      b.minor == beaconMinor
    );
    if (found && !_isInside) {
      _isInside = true;
      lastEnter = DateTime.now();
      notifyListeners();
    } else if (!found && _isInside) {
      _isInside = false;
      lastExit = DateTime.now();
      notifyListeners();
    }
  }

  // For testing: fallback to mock toggle if needed
  void toggleMock() {
    if (_isInside) {
      _isInside = false;
      lastExit = DateTime.now();
    } else {
      _isInside = true;
      lastEnter = DateTime.now();
    }
    notifyListeners();
  }
}
