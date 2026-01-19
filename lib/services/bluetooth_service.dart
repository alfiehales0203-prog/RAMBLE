import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../models/audio_note.dart';

class BluetoothService {
  fbp.BluetoothDevice? device;
  fbp.BluetoothCharacteristic? commandCharacteristic; // TX: Phone -> ESP32 (Write)
  fbp.BluetoothCharacteristic? statusCharacteristic;  // RX: ESP32 -> Phone (Notify)
  fbp.BluetoothCharacteristic? dataCharacteristic;    // File data (Notify)

  List<int> receivingBuffer = [];
  String? currentFilename;
  int? currentFilesize;
  int bytesReceived = 0;

  Function(String)? onStatusUpdate;
  Function(int, int)? onProgress; // current, total files
  Function()? onSyncComplete;

  // UUIDs - Matching ESP32 BLE Service
  static final fbp.Guid serviceUuid = fbp.Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  static final fbp.Guid commandCharUuid = fbp.Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8"); // TX: Phone -> ESP32 (Write)
  static final fbp.Guid statusCharUuid = fbp.Guid("1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e");   // RX: ESP32 -> Phone (Notify)
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

          // Log all discovered devices for debugging
          if (deviceName.isNotEmpty && !discoveredDevices.contains(deviceName)) {
            discoveredDevices.add(deviceName);
            print('BLE: Found device: $deviceName');
            print('BLE: Services: ${result.advertisementData.serviceUuids}');
          }

          // Look for device with name "Ramble Device" or specific service UUID
          // Also check for common ESP32 names
          if (deviceName == "Ramble Device" ||
              deviceName == "ESP32" ||
              deviceName.toLowerCase().contains("ramble") ||
              deviceName.toLowerCase().contains("esp32") ||
              result.advertisementData.serviceUuids.contains(serviceUuid)) {
            foundDevice = result.device;
            print('BLE: MATCH FOUND - $deviceName');
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
        // Show discovered devices for debugging
        String debugInfo = discoveredDevices.isEmpty
            ? 'No BLE devices found'
            : 'Found: ${discoveredDevices.join(", ")}';
        print('BLE: Scan complete - $debugInfo');
        onStatusUpdate?.call('Device not found. $debugInfo');
      }

      return foundDevice;
    } catch (e) {
      print('Error finding device: $e');
      onStatusUpdate?.call('Scan error: $e');
      return null;
    }
  }

  // Connect to device
  Future<bool> connect(fbp.BluetoothDevice bleDevice) async {
    try {
      device = bleDevice;
      onStatusUpdate?.call('Connecting to ${device!.platformName}...');

      // Connect to device with auto-reconnect
      await device!.connect(
        timeout: Duration(seconds: 30),
        autoConnect: false,  // Don't auto-reconnect, we want explicit control
      );

      // Request larger MTU for faster transfers (max 512 on Android)
      int mtu = await device!.requestMtu(512);
      print('BLE: Negotiated MTU: $mtu bytes');

      onStatusUpdate?.call('Discovering services...');

      // Discover services
      List<fbp.BluetoothService> services = await device!.discoverServices();

      print('BLE: Found ${services.length} services');

      // Find the correct service and characteristics
      for (fbp.BluetoothService service in services) {
        print('BLE: Service UUID: ${service.uuid}');
        print('BLE: Expected Service UUID: $serviceUuid');

        // Print all characteristics for this service
        for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
          print('BLE:   Characteristic UUID: ${characteristic.uuid}');
          print('BLE:   Properties: Read=${characteristic.properties.read}, Write=${characteristic.properties.write}, Notify=${characteristic.properties.notify}, WriteWithoutResponse=${characteristic.properties.writeWithoutResponse}');
        }

        // Try to match by service UUID first
        bool isMatchingService = service.uuid == serviceUuid;

        // If no match, try to find ANY service with write and notify characteristics
        if (!isMatchingService && commandCharacteristic == null && statusCharacteristic == null) {
          bool hasWrite = service.characteristics.any((c) => c.properties.write || c.properties.writeWithoutResponse);
          bool hasNotify = service.characteristics.any((c) => c.properties.notify);
          if (hasWrite && hasNotify) {
            print('BLE: Found potential service with write and notify capabilities');
            isMatchingService = true;
          }
        }

        if (isMatchingService) {
          print('BLE: Using service: ${service.uuid}');

          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            print('BLE: Checking characteristic: ${characteristic.uuid}');

            // Match characteristics by UUID
            if (characteristic.uuid == commandCharUuid) {
              commandCharacteristic = characteristic;
              print('BLE: Found Command characteristic (TX)!');
            } else if (characteristic.uuid == statusCharUuid) {
              statusCharacteristic = characteristic;
              print('BLE: Found Status characteristic (RX)!');
              // Subscribe to status notifications
              await statusCharacteristic!.setNotifyValue(true);
            } else if (characteristic.uuid == dataCharUuid) {
              dataCharacteristic = characteristic;
              print('BLE: Found Data characteristic!');
              // Subscribe to data notifications
              await dataCharacteristic!.setNotifyValue(true);
            }
          }
        }
      }

      if (commandCharacteristic == null || statusCharacteristic == null || dataCharacteristic == null) {
        String missingChars = '';
        if (commandCharacteristic == null) missingChars += 'Command ';
        if (statusCharacteristic == null) missingChars += 'Status ';
        if (dataCharacteristic == null) missingChars += 'Data ';

        print('BLE: Missing characteristics: $missingChars');
        onStatusUpdate?.call('Could not find $missingChars characteristics');
        return false;
      }

      // Listen to status updates
      statusCharacteristic!.lastValueStream.listen((value) {
        _handleStatusData(Uint8List.fromList(value));
      });

      // Listen to file data
      dataCharacteristic!.lastValueStream.listen((value) {
        _handleFileData(Uint8List.fromList(value));
      });

      // Give BLE stack time to stabilize after setup
      await Future.delayed(Duration(milliseconds: 500));

      onStatusUpdate?.call('Connected!');
      return true;

    } catch (e) {
      print('Connection error: $e');
      onStatusUpdate?.call('Connection failed: $e');
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      if (statusCharacteristic != null) {
        await statusCharacteristic!.setNotifyValue(false);
      }
      if (dataCharacteristic != null) {
        await dataCharacteristic!.setNotifyValue(false);
      }
      await device?.disconnect();
      device = null;
      commandCharacteristic = null;
      statusCharacteristic = null;
      dataCharacteristic = null;
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  // Send SYNC command and receive files
  Future<void> syncFiles() async {
    print('BLE: syncFiles() called');
    print('BLE: device = $device');
    print('BLE: commandCharacteristic = $commandCharacteristic');

    if (device == null || commandCharacteristic == null) {
      print('BLE: Not connected - device or characteristic is null');
      onStatusUpdate?.call('Not connected');
      return;
    }

    try {
      onStatusUpdate?.call('Starting sync...');
      print('BLE: Sending SYNC command...');

      // Small delay before write
      await Future.delayed(Duration(milliseconds: 200));

      // Send SYNC command with longer timeout
      await commandCharacteristic!.write(
        Uint8List.fromList('SYNC'.codeUnits),
        withoutResponse: false,
        timeout: 30,  // 30 second timeout
      );

      print('BLE: SYNC command sent successfully');
      onStatusUpdate?.call('Waiting for files...');

    } catch (e, stackTrace) {
      print('BLE: Sync error: $e');
      print('BLE: Stack trace: $stackTrace');
      onStatusUpdate?.call('Sync error: $e');
    }
  }

  // Handle status messages from ESP32
  void _handleStatusData(Uint8List data) {
    String received = String.fromCharCodes(data);
    received = received.trim();

    print('BLE Status: $received');

    if (received == 'SYNC_START') {
      onStatusUpdate?.call('ESP32 starting transfer...');
      print('BLE: ===== SYNC START =====');
    } else if (received == 'SYNC_COMPLETE') {
      print('BLE: ===== SYNC COMPLETE =====');
      onStatusUpdate?.call('Sync complete!');
      onSyncComplete?.call();
    } else if (received.startsWith('FILE:')) {
      // Parse file header: "FILE:filename,size"
      String fileInfo = received.substring(5);
      List<String> parts = fileInfo.split(',');

      if (parts.length == 2) {
        currentFilename = parts[0];
        currentFilesize = int.tryParse(parts[1]);
        bytesReceived = 0;
        receivingBuffer.clear();

        onStatusUpdate?.call('Receiving: $currentFilename');
        print('BLE: ===== NEW FILE =====');
        print('BLE: Filename: $currentFilename');
        print('BLE: Expected size: $currentFilesize bytes');
        print('BLE: Buffer cleared, ready to receive...');
      }
    } else if (received == 'PONG') {
      print('BLE: PONG received');
    } else {
      onStatusUpdate?.call(received);
    }
  }

  // Handle file data from ESP32
  void _handleFileData(Uint8List data) {
    if (currentFilename != null && currentFilesize != null) {
      // Receiving file data - keep this as fast as possible!
      receivingBuffer.addAll(data);
      bytesReceived += data.length;

      // Only update UI every 10KB to reduce overhead
      if (bytesReceived % 10240 == 0) {
        int percentage = ((bytesReceived / currentFilesize!) * 100).round();
        onStatusUpdate?.call('Receiving: $percentage%');
      }

      // Check if file complete
      if (bytesReceived >= currentFilesize!) {
        print('BLE: FILE COMPLETE! $bytesReceived bytes received. Saving...');
        saveReceivedFile();
        currentFilename = null;
        currentFilesize = null;
      }
    }
  }

  // Send ACK to ESP32 to confirm chunk received
  Future<void> _sendAck() async {
    if (commandCharacteristic != null) {
      try {
        await commandCharacteristic!.write(
          Uint8List.fromList('ACK'.codeUnits),
          withoutResponse: false  // Wait for write confirmation
        );
      } catch (e) {
        print('BLE: Error sending ACK: $e');
      }
    }
  }

  // Save received file to phone storage and add to Hive database
  Future<void> saveReceivedFile() async {
    try {
      if (currentFilename == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$currentFilename';

      // Save the audio file
      File file = File(filePath);
      await file.writeAsBytes(receivingBuffer);

      // Create AudioNote entry in Hive database
      final audioNotesBox = Hive.box<AudioNote>('audioNotes');

      final audioNote = AudioNote(
        filename: currentFilename!,
        timestamp: DateTime.now(),
        isTranscribed: false,
        audioFilePath: filePath,
      );

      await audioNotesBox.add(audioNote);

      print('BLE: Saved file and created AudioNote: $currentFilename');
      onStatusUpdate?.call('Saved: $currentFilename');

      receivingBuffer.clear();
    } catch (e) {
      print('Error saving file: $e');
      onStatusUpdate?.call('Error saving: $e');
    }
  }

  // Send command to delete files on ESP32
  Future<void> deleteFilesOnDevice() async {
    if (device == null || commandCharacteristic == null) {
      return;
    }

    try {
      await commandCharacteristic!.write(Uint8List.fromList('DELETE'.codeUnits), withoutResponse: false);

      onStatusUpdate?.call('Delete command sent');
    } catch (e) {
      print('Delete error: $e');
    }
  }

  // Test connection with PING
  Future<bool> testConnection() async {
    if (device == null || commandCharacteristic == null) {
      return false;
    }

    try {
      await commandCharacteristic!.write(Uint8List.fromList('PING'.codeUnits), withoutResponse: false);

      // Wait for PONG response
      await Future.delayed(Duration(milliseconds: 500));

      return true;
    } catch (e) {
      print('Ping error: $e');
      return false;
    }
  }
}
