import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../models/audio_note.dart';

class BluetoothService {
  fbp.BluetoothDevice? device;
  fbp.BluetoothCharacteristic? commandCharacteristic; // TX: Phone -> ESP32 (Write)
  fbp.BluetoothCharacteristic? dataCharacteristic;    // File data (Notify)

  List<int> receivingBuffer = [];
  String? currentFilename;
  int? currentFilesize;
  int bytesReceived = 0;
  int _ackCount = 0;

  StreamSubscription? _dataSubscription;

  Function(String)? onStatusUpdate;
  Function(int, int)? onProgress; // current, total files
  Function()? onSyncComplete;

  // UUIDs - Matching ESP32 BLE Service
  static final fbp.Guid serviceUuid = fbp.Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  static final fbp.Guid commandCharUuid = fbp.Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8"); // TX: Phone -> ESP32 (Write)
  static final fbp.Guid dataCharUuid = fbp.Guid("af0badb1-5b99-43cd-917a-a77bc549e970");     // Data transfers (Notify)

  // Scan for Ramble Device
  Future<fbp.BluetoothDevice?> findRambleDevice() async {
    try {
      // Check if Bluetooth is supported
      if (await fbp.FlutterBluePlus.isSupported == false) {
        onStatusUpdate?.call('Bluetooth not supported');
        return null;
      }

      // Turn on Bluetooth if not enabled
      if (await fbp.FlutterBluePlus.adapterState.first != fbp.BluetoothAdapterState.on) {
        onStatusUpdate?.call('Please enable Bluetooth');
        return null;
      }

      onStatusUpdate?.call('Scanning for Ramble Device...');

      fbp.BluetoothDevice? foundDevice;
      List<String> discoveredDevices = [];

      // Start scanning
      await fbp.FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      var subscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          String deviceName = result.device.platformName;

          if (deviceName.isNotEmpty && !discoveredDevices.contains(deviceName)) {
            discoveredDevices.add(deviceName);
          }

          if (deviceName == "Ramble Device" ||
              deviceName == "ESP32" ||
              deviceName.toLowerCase().contains("ramble") ||
              deviceName.toLowerCase().contains("esp32") ||
              result.advertisementData.serviceUuids.contains(serviceUuid)) {
            foundDevice = result.device;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(Duration(seconds: 15));
      await subscription.cancel();
      await fbp.FlutterBluePlus.stopScan();

      if (foundDevice != null) {
        onStatusUpdate?.call('Found ${foundDevice!.platformName}');
      } else {
        String debugInfo = discoveredDevices.isEmpty
            ? 'No BLE devices found'
            : 'Found: ${discoveredDevices.join(", ")}';
        onStatusUpdate?.call('Device not found. $debugInfo');
      }

      return foundDevice;
    } catch (e) {
      onStatusUpdate?.call('Scan error: $e');
      return null;
    }
  }

  // Connect to device
  Future<bool> connect(fbp.BluetoothDevice bleDevice) async {
    try {
      device = bleDevice;
      onStatusUpdate?.call('Connecting to ${device!.platformName}...');

      // Connect to device
      await device!.connect(
        timeout: Duration(seconds: 30),
        autoConnect: false,
      );

      // Clear cached services to get fresh characteristic properties
      await device!.clearGattCache();

      // Request larger MTU for faster transfers (max 512 on Android)
      await device!.requestMtu(512);

      onStatusUpdate?.call('Discovering services...');

      // Discover services
      List<fbp.BluetoothService> services = await device!.discoverServices();

      // Find the correct service and characteristics
      for (fbp.BluetoothService service in services) {
        if (service.uuid == serviceUuid) {
          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == commandCharUuid) {
              commandCharacteristic = characteristic;
            } else if (characteristic.uuid == dataCharUuid) {
              dataCharacteristic = characteristic;
            }
          }
        }
      }

      if (commandCharacteristic == null || dataCharacteristic == null) {
        onStatusUpdate?.call('Could not find required characteristics');
        return false;
      }

      // Cancel any existing subscriptions
      await _dataSubscription?.cancel();

      print('BLE: Setting up data notification listener...');

      // Subscribe to data notifications
      _dataSubscription = dataCharacteristic!.onValueReceived.listen((value) {
        print('BLE: *** NOTIFICATION RECEIVED *** ${value.length} bytes');
        _handleFileData(Uint8List.fromList(value));
      }, onError: (error) {
        print('BLE: Notification stream error: $error');
      }, onDone: () {
        print('BLE: Notification stream closed');
      });

      // Enable notifications AFTER setting up listeners
      print('BLE: Enabling notifications on data characteristic...');
      await dataCharacteristic!.setNotifyValue(true);
      print('BLE: Notifications enabled!');

      onStatusUpdate?.call('Connected!');
      return true;

    } catch (e) {
      onStatusUpdate?.call('Connection failed: $e');
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      // Cancel subscriptions first
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      if (dataCharacteristic != null) {
        await dataCharacteristic!.setNotifyValue(false);
      }
      await device?.disconnect();
      device = null;
      commandCharacteristic = null;
      dataCharacteristic = null;
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  // Send SYNC command and receive files
  Future<void> syncFilesRobust() async {
    if (device == null || commandCharacteristic == null) {
      onStatusUpdate?.call('Not connected');
      return;
    }

    // Reset sync state
    _ackCount = 0;
    currentFilename = null;
    currentFilesize = null;
    bytesReceived = 0;
    receivingBuffer.clear();

    onStatusUpdate?.call('Starting sync...');

    try {
      // Send SYNC command to ESP32 to start file transfer
      await commandCharacteristic!.write(
        Uint8List.fromList('SYNC'.codeUnits),
        withoutResponse: true,
      );
      print('BLE: SYNC command sent');
      onStatusUpdate?.call('Syncing files...');
    } catch (e) {
      print('BLE: SYNC command error: $e');
      onStatusUpdate?.call('Sync command failed');
    }
  }

  // Handle file data from ESP32 via notifications
  void _handleFileData(Uint8List data) async {
    // First, check if this is a text command (not binary file data)
    if (data.length < 100 && _looksLikeTextCommand(data)) {
      String text = String.fromCharCodes(data).trim();
      print('BLE DATA (text): $text');

      // Handle as status message
      if (text == 'SYNC_START') {
        onStatusUpdate?.call('Starting transfer...');
        return;
      } else if (text == 'SYNC_COMPLETE') {
        onStatusUpdate?.call('Sync complete!');
        onSyncComplete?.call();
        return;
      } else if (text.startsWith('FILE:')) {
        String fileInfo = text.substring(5);
        List<String> parts = fileInfo.split(',');
        if (parts.length == 2) {
          currentFilename = parts[0];
          currentFilesize = int.tryParse(parts[1]);
          bytesReceived = 0;
          receivingBuffer.clear();
          _ackCount = 0;
          print('BLE: Ready to receive file: $currentFilename ($currentFilesize bytes)');
          onStatusUpdate?.call('Receiving: $currentFilename');
          
          // Send ACK for file header
          _sendAckFast();
        }
        return;
      } else if (text.startsWith('ERROR:') || text.startsWith('STATUS:') ||
                 text == 'PONG' || text == 'LIST_COMPLETE' || text == 'DELETE_COMPLETE') {
        onStatusUpdate?.call(text);
        return;
      }
    }

    // This is binary file data
    if (currentFilename == null || currentFilesize == null) {
      print('BLE DATA: Received ${data.length} bytes but NO FILE CONTEXT');
      return;
    }

    receivingBuffer.addAll(data);
    bytesReceived += data.length;

    // Send ACK immediately so ESP32 can send next chunk
    _sendAckFast();

    // Update progress every 4KB
    if (bytesReceived % 4096 < 200) {
      int percentage = ((bytesReceived / currentFilesize!) * 100).round();
      print('BLE: Progress $bytesReceived / $currentFilesize bytes ($percentage%)');
      onStatusUpdate?.call('Receiving: $percentage%');
    }

    // Check if file complete
    if (bytesReceived >= currentFilesize!) {
      String filenameToSave = currentFilename!;
      List<int> dataToSave = List.from(receivingBuffer);

      print('BLE: File complete! Saving $filenameToSave (${dataToSave.length} bytes)');

      currentFilename = null;
      currentFilesize = null;
      receivingBuffer.clear();
      bytesReceived = 0;

      await _saveFile(filenameToSave, dataToSave);
    }
  }

  // Check if data looks like a text command (printable ASCII, no binary)
  bool _looksLikeTextCommand(Uint8List data) {
    for (int byte in data) {
      // Allow printable ASCII (32-126), newline, carriage return, tab
      if (byte < 32 && byte != 10 && byte != 13 && byte != 9) {
        return false;
      }
      if (byte > 126) {
        return false;
      }
    }
    return true;
  }

  // Save file to storage and database
  Future<void> _saveFile(String filename, List<int> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      File file = File(filePath);
      await file.writeAsBytes(data);

      final audioNotesBox = Hive.box<AudioNote>('audioNotes');
      final audioNote = AudioNote(
        filename: filename,
        timestamp: DateTime.now(),
        isTranscribed: false,
        audioFilePath: filePath,
      );
      await audioNotesBox.add(audioNote);

      onStatusUpdate?.call('Saved: $filename');
    } catch (e) {
      onStatusUpdate?.call('Error saving: $e');
    }
  }

  // Send ACK to ESP32 to confirm chunk received - FIRE AND FORGET for speed
  void _sendAckFast() {
    if (commandCharacteristic != null) {
      _ackCount++;
      if (_ackCount == 1 || _ackCount % 50 == 0) {
        print('BLE: Sending ACK #$_ackCount');
      }

      // Fire and forget - don't await, don't delay
      commandCharacteristic!.write(
        Uint8List.fromList([0x06]),
        withoutResponse: true,
      ).catchError((e) {
        print('BLE: ACK send error: $e');
      });
    }
  }

  // Send command to delete files on ESP32
  Future<void> deleteFilesOnDevice() async {
    if (device == null || commandCharacteristic == null) return;

    try {
      await commandCharacteristic!.write(
        Uint8List.fromList('DELETE'.codeUnits),
        withoutResponse: true,
      );
      onStatusUpdate?.call('Delete command sent');
    } catch (e) {
      // Ignore errors
    }
  }

  // Test function to verify ACK and command sending
  Future<void> testAck() async {
    if (commandCharacteristic != null) {
      print('Testing ACK send...');
      try {
        // Test sending ACK
        await commandCharacteristic!.write(
          Uint8List.fromList([0x06]),
          withoutResponse: true,
        );
        print('Test ACK sent successfully');
        
        // Also try sending a test string
        await Future.delayed(Duration(milliseconds: 100));
        await commandCharacteristic!.write(
          Uint8List.fromList('TEST'.codeUnits),
          withoutResponse: true,
        );
        print('Test string sent');
        
      } catch (e) {
        print('Test send error: $e');
      }
    }
  }
}
