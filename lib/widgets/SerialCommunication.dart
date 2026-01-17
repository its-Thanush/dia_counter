import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:convert';
import 'dart:typed_data';

class SerialService {
  static final SerialService _instance = SerialService._internal();
  factory SerialService() => _instance;
  SerialService._internal();
  String _buffer = '';

  UsbPort? _port;
  bool isConnected = false;
  Function(bool)? onConnectionChanged;

  Function(Map<String, dynamic>)? onDataReceived;

  // Connect to device
  Future<bool> connect() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        print("No devices found");
        isConnected = false;
        onConnectionChanged?.call(false);
        return false;
      }

      print("Found ${devices.length} device(s)");

      _port = await devices[0].create();

      if (_port == null) {
        print("Failed to create port");
        isConnected = false;
        onConnectionChanged?.call(false);
        return false;
      }

      bool openResult = await _port!.open();

      if (!openResult) {
        print("Failed to open port");
        isConnected = false;
        onConnectionChanged?.call(false);
        return false;
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      print("Connected successfully!");

      _buffer = '';
      await Future.delayed(Duration(milliseconds: 1000)); // Increase delay

      isConnected = true;
      onConnectionChanged?.call(true);
      startListening();

      return true;
    } catch (e) {
      print("Connection error: $e");
      isConnected = false;
      onConnectionChanged?.call(false);
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

  // Check connection status
  Future<bool> checkConnection() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isEmpty || _port == null) {
        if (isConnected) {
          isConnected = false;
          onConnectionChanged?.call(false);
        }
        return false;
      }

      if (!isConnected) {
        isConnected = true;
        onConnectionChanged?.call(true);
      }
      return true;
    } catch (e) {
      print("Error checking connection: $e");
      if (isConnected) {
        isConnected = false;
        onConnectionChanged?.call(false);
      }
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      await _port?.close();
      _port = null;
      isConnected = false;
      onConnectionChanged?.call(false);
      print("Disconnected");
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

}