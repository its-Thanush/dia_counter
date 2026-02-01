import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:convert';
import 'dart:typed_data';

class SerialService {
  static final SerialService _instance = SerialService._internal();
  factory SerialService() => _instance;
  SerialService._internal();
  String _buffer = '';
  String _bluetoothBuffer = '';

  UsbPort? _port;
  UsbPort? _bluetoothPort;
  bool isConnected = false;
  bool isBluetoothConnected = false;
  Function(bool)? onConnectionChanged;
  Function(bool)? onBluetoothConnectionChanged;

  Function(Map<String, dynamic>)? onDataReceived;
  Function(Map<String, dynamic>)? onBluetoothDataReceived;

  Function(String)? onDeviceInfoUpdate;

  Future<UsbPort?> _connectToNodeMCU() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        print("No devices found");
        onDeviceInfoUpdate?.call("❌ No devices found");
        return null;
      }

      print("Found ${devices.length} device(s)");
      onDeviceInfoUpdate?.call("📱 Found ${devices.length} device(s)");

      UsbDevice? nodeMCUDevice;
      for (var device in devices) {
        String deviceInfo = "Device: ${device.productName}, VID: ${device.vid}, PID: ${device.pid}";
        print(deviceInfo);
        onDeviceInfoUpdate?.call("🔍 $deviceInfo");

        // IMPORTANT: Update these VID/PID values based on YOUR NodeMCU's actual values
        if (device.productName?.toLowerCase().contains('jtag') == true ||
            device.productName?.toLowerCase().contains('serial debug') == true ||
            device.vid == 4292 || device.vid == 6790) {
          nodeMCUDevice = device;
          String foundMsg = "✅ NodeMCU found: ${device.productName} (VID: ${device.vid}, PID: ${device.pid})";
          print(foundMsg);
          onDeviceInfoUpdate?.call(foundMsg);
          break;
        }
      }

      if (nodeMCUDevice == null) {
        print("NodeMCU not found");
        onDeviceInfoUpdate?.call("❌ NodeMCU not found! Check VID/PID above");
        return null;
      }

      UsbPort? port = await nodeMCUDevice.create();

      if (port == null) {
        print("Failed to create NodeMCU port");
        onDeviceInfoUpdate?.call("❌ Failed to create NodeMCU port");
        return null;
      }

      bool openResult = await port.open();

      if (!openResult) {
        print("Failed to open NodeMCU port");
        onDeviceInfoUpdate?.call("❌ Failed to open NodeMCU port");
        return null;
      }

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      print("NodeMCU Connected successfully!");
      onDeviceInfoUpdate?.call("✅ NodeMCU Connected successfully!");
      return port;
    } catch (e) {
      print("NodeMCU Connection error: $e");
      onDeviceInfoUpdate?.call("❌ NodeMCU Error: $e");
      return null;
    }
  }

  Future<UsbPort?> _connectToBluetoothDongle() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        print("No devices found");
        onDeviceInfoUpdate?.call("❌ No devices found for Bluetooth");
        return null;
      }

      UsbDevice? bluetoothDevice;
      for (var device in devices) {
        String deviceInfo = "BT Check - Device: ${device.productName}, VID: ${device.vid}, PID: ${device.pid}";
        print(deviceInfo);
        onDeviceInfoUpdate?.call("🔍 $deviceInfo");

        if (device.productName?.toLowerCase().contains('hid') == true ||
            device.productName?.toLowerCase().contains('keyboard') == true ||
            device.vid == 65535) {
          bluetoothDevice = device;
          String foundMsg = "✅ Bluetooth found: ${device.productName} (VID: ${device.vid}, PID: ${device.pid})";
          print(foundMsg);
          onDeviceInfoUpdate?.call(foundMsg);
          break;
        }
      }

      if (bluetoothDevice == null) {
        print("Bluetooth dongle not found");
        onDeviceInfoUpdate?.call("⚠️ Bluetooth dongle not found (Check VID/PID above)");
        return null;
      }

      UsbPort? port = await bluetoothDevice.create();

      if (port == null) {
        print("Failed to create Bluetooth port");
        onDeviceInfoUpdate?.call("❌ Failed to create Bluetooth port");
        return null;
      }

      bool openResult = await port.open();

      if (!openResult) {
        print("Failed to open Bluetooth port");
        onDeviceInfoUpdate?.call("❌ Failed to open Bluetooth port");
        return null;
      }

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      print("Bluetooth Dongle Connected successfully!");
      onDeviceInfoUpdate?.call("✅ Bluetooth Connected successfully!");
      return port;
    } catch (e) {
      print("Bluetooth Connection error: $e");
      onDeviceInfoUpdate?.call("❌ Bluetooth Error: $e");
      return null;
    }
  }

  Future<bool> connect() async {
    try {
      // Step 1: Connect to NodeMCU
      print("Attempting to connect to NodeMCU...");
      onDeviceInfoUpdate?.call("⏳ Connecting to NodeMCU...");
      _port = await _connectToNodeMCU();

      if (_port == null) {
        print("Failed to connect to NodeMCU");
        onDeviceInfoUpdate?.call("❌ Failed to connect to NodeMCU");
        isConnected = false;
        onConnectionChanged?.call(false);
        return false;
      }

      isConnected = true;
      onConnectionChanged?.call(true);
      _buffer = '';
      await Future.delayed(Duration(milliseconds: 500));
      startListening(); // Start listening to NodeMCU

      // Step 2: Connect to Bluetooth dongle
      print("Attempting to connect to Bluetooth dongle...");
      onDeviceInfoUpdate?.call("⏳ Connecting to Bluetooth dongle...");
      _bluetoothPort = await _connectToBluetoothDongle();

      if (_bluetoothPort == null) {
        print("Warning: Bluetooth dongle not found, but NodeMCU is connected");
        onDeviceInfoUpdate?.call("⚠️ NodeMCU OK, Bluetooth not available");
        isBluetoothConnected = false;
        onBluetoothConnectionChanged?.call(false);
        return true; // NodeMCU connected successfully
      }

      isBluetoothConnected = true;
      onBluetoothConnectionChanged?.call(true);
      _bluetoothBuffer = '';
      await Future.delayed(Duration(milliseconds: 500));
      startBluetoothListening(); // Start listening to Bluetooth

      print("Both NodeMCU and Bluetooth connected successfully!");
      onDeviceInfoUpdate?.call("✅ Both devices connected successfully!");
      return true;

    } catch (e) {
      print("Connection error: $e");
      onDeviceInfoUpdate?.call("❌ Connection error: $e");
      isConnected = false;
      onConnectionChanged?.call(false);
      isBluetoothConnected = false;
      onBluetoothConnectionChanged?.call(false);
      return false;
    }
  }

  // Send data to NodeMCU
  Future<void> sendData(String data) async {
    if (_port == null) {
      print("Port not connected");
      return;
    }

    try {
      String message = data + '\n';
      await _port!.write(Uint8List.fromList(message.codeUnits));
      print("Sent: $message");
    } catch (e) {
      print("Error sending data: $e");
      isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  // Send JSON data
  Future<void> sendJsonData(Map<String, dynamic> data) async {
    if (_port == null) {
      print("Port not connected");
      return;
    }

    try {
      String jsonString = json.encode(data);
      jsonString += '\n';
      await _port!.write(Uint8List.fromList(jsonString.codeUnits));
      print("Sent: $jsonString");
    } catch (e) {
      print("Error sending data: $e");
      isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  void startListening() {
    _port?.inputStream?.listen((Uint8List data) {
      String received = String.fromCharCodes(data);
      _buffer += received;

      // Process complete messages (ending with newline)
      while (_buffer.contains('\n')) {
        int newlineIndex = _buffer.indexOf('\n');
        String message = _buffer.substring(0, newlineIndex).trim();
        _buffer = _buffer.substring(newlineIndex + 1);

        if (message.isNotEmpty) {
          try {
            Map<String, dynamic> jsonData = json.decode(message);
            onDataReceived?.call(jsonData);
            print("Received: $jsonData");
          } catch (e) {
            print("Error parsing JSON: $e, Raw: $message");
          }
        }
      }
    });
  }

  // NEW: Bluetooth listening
  void startBluetoothListening() {
    _bluetoothPort?.inputStream?.listen((Uint8List data) {
      String received = String.fromCharCodes(data);
      _bluetoothBuffer += received;

      // Process complete messages (ending with newline)
      while (_bluetoothBuffer.contains('\n')) {
        int newlineIndex = _bluetoothBuffer.indexOf('\n');
        String message = _bluetoothBuffer.substring(0, newlineIndex).trim();
        _bluetoothBuffer = _bluetoothBuffer.substring(newlineIndex + 1);

        if (message.isNotEmpty) {
          try {
            Map<String, dynamic> jsonData = json.decode(message);
            onBluetoothDataReceived?.call(jsonData);
            print("Received from Bluetooth: $jsonData");
          } catch (e) {
            print("Error parsing Bluetooth JSON: $e, Raw: $message");
          }
        }
      }
    });
  }

  // Check connection status
  Future<bool> checkConnection() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      bool nodeConnected = devices.isNotEmpty && _port != null;
      bool btConnected = devices.isNotEmpty && _bluetoothPort != null;

      // Update NodeMCU connection status
      if (nodeConnected != isConnected) {
        isConnected = nodeConnected;
        onConnectionChanged?.call(isConnected);
      }

      // Update Bluetooth connection status
      if (btConnected != isBluetoothConnected) {
        isBluetoothConnected = btConnected;
        onBluetoothConnectionChanged?.call(isBluetoothConnected);
      }

      return isConnected; // Return NodeMCU status as primary
    } catch (e) {
      print("Error checking connection: $e");
      if (isConnected) {
        isConnected = false;
        onConnectionChanged?.call(false);
      }
      if (isBluetoothConnected) {
        isBluetoothConnected = false;
        onBluetoothConnectionChanged?.call(false);
      }
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      await _port?.close();
      await _bluetoothPort?.close();
      _port = null;
      _bluetoothPort = null;
      isConnected = false;
      isBluetoothConnected = false;
      onConnectionChanged?.call(false);
      onBluetoothConnectionChanged?.call(false);
      print("Disconnected from both devices");
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

}