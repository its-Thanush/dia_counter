import 'dart:async';
import 'dart:convert';

import 'package:dia_counter/customtext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../widgets/SerialCommunication.dart';

class Mainscreen extends StatefulWidget {
  const Mainscreen({super.key});

  @override
  State<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends State<Mainscreen> {
  final TextEditingController qrController = TextEditingController();
  final TextEditingController actualSectionController = TextEditingController();
  final TextEditingController setPointController = TextEditingController();
  final TextEditingController ScaleController = TextEditingController();
  final TextEditingController spSectionController = TextEditingController();

  String actualSectionValue = "0000.00";


  final _formKey = GlobalKey<FormState>();

  final SerialService serialService = SerialService();
  bool isNodeMCUOnline = false;
  Timer? connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    actualSectionController.text = '0000.00';
    setPointController.text = '0000.00';
    ScaleController.text = '0000.00';

    serialService.onConnectionChanged = (bool status) {
      setState(() {
        isNodeMCUOnline = status;
      });
    };

    connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkNodeMCUConnection();
    });


    serialService.onDataReceived = (Map<String, dynamic> data) {
      if (data.containsKey('act')) {
        setState(() {
          actualSectionValue = data['act'].toString();
        });
      }
    };


    // Try to connect on startup
    _connectToNodeMCU();
  }

  Future<void> _connectToNodeMCU() async {
    await serialService.connect();
  }

  Future<void> _checkNodeMCUConnection() async {
    bool connected = await serialService.checkConnection();
    if (connected != isNodeMCUOnline) {
      setState(() {
        isNodeMCUOnline = connected;
      });
    }
  }

  @override
  void dispose() {
    connectionCheckTimer?.cancel();
    qrController.dispose();
    actualSectionController.dispose();
    setPointController.dispose();
    spSectionController.dispose();
    ScaleController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      qrController.clear();
      actualSectionController.text = '0000.00';
      setPointController.text = '0000.00';
      ScaleController.text = '0000.00';
      spSectionController.clear();
    });
    _formKey.currentState?.reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form Reset Successfully'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitAndPrint() async {
    if (_formKey.currentState!.validate()) {
      if (!isNodeMCUOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NodeMCU is not connected!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Prepare JSON data
      Map<String, dynamic> jsonData = {
        "setpoint": setPointController.text,
        "scale": ScaleController.text,
        "sp": spSectionController.text,
      };

      print("Json ----->"+jsonEncode(jsonData));

      try {
        await serialService.sendJsonData(jsonData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data sent to NodeMCU:\n'
                  'Set Point: ${setPointController.text}\n'
                  'Scale: ${ScaleController.text}\n'
                  'SP Section: ${spSectionController.text}',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green[700],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending data: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFloatInput(String value) {
    String cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');

    // Handle multiple decimal points
    List<String> parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    }

    return cleaned;
  }

  void _formatFloatOnChange(TextEditingController controller, String value) {
    String formatted = _formatFloatInput(value);

    if (formatted.contains('.')) {
      List<String> parts = formatted.split('.');
      String integerPart = parts[0].substring(0, parts[0].length > 4 ? 4 : parts[0].length);
      String decimalPart = parts.length > 1 ? parts[1].substring(0, parts[1].length > 2 ? 2 : parts[1].length) : '';
    } else {
      formatted = formatted.substring(0, formatted.length > 4 ? 4 : formatted.length);
    }

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _formatFloatOnBlur(TextEditingController controller) {
    String value = controller.text;

    if (value.isEmpty || value == '.') {
      controller.text = '0000.00';
      return;
    }

    // Parse and format
    double? parsed = double.tryParse(value);
    if (parsed != null) {
      controller.text = parsed.toStringAsFixed(2).padLeft(7, '0');
    } else {
      controller.text = '0000.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        toolbarHeight: 30,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "DIA COUNTER",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Spacer(),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNodeMCUOnline ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (isNodeMCUOnline ? Colors.green : Colors.red)
                        .withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("QR Code"),
                          const SizedBox(height: 5),
                          const CustomText(
                            text: "2954854215151411551515951985",
                            size: 22,
                            weight: FontWeight.bold,
                            textOverflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(20),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.shade200,
                        border: Border.all(color: Colors.purple),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Actual Section"),
                          const SizedBox(height: 5),
                           CustomText(
                            text: actualSectionValue,
                            size: 22,
                            weight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildLabel("Set Point"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: setPointController,
                          hintText: "0000.00",
                          prefixIcon: Icons.track_changes,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _formatFloatOnChange(setPointController, value),
                          onTap: () {
                            if (setPointController.text == '0000.00') {
                              setPointController.clear();
                            }
                          },
                          onEditingComplete: () {
                            _formatFloatOnBlur(setPointController);
                            FocusScope.of(context).nextFocus();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter set point';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildLabel("Scale"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: ScaleController,
                          hintText: "0000.00",
                          prefixIcon: Icons.track_changes,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _formatFloatOnChange(ScaleController, value),
                          onTap: () {
                            if (ScaleController.text == '0000.00') {
                              ScaleController.clear();
                            }
                          },
                          onEditingComplete: () {
                            _formatFloatOnBlur(ScaleController);
                            FocusScope.of(context).nextFocus();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter scale';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildLabel("SP"),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: spSectionController,
                          hintText: "Enter value (0-9)",
                          prefixIcon: Icons.filter_9_plus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter SP section';
                            }
                            int? intValue = int.tryParse(value);
                            if (intValue == null || intValue < 0 || intValue > 9) {
                              return 'Value must be between 0-9';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const Gap(20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 200,
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh, size: 24),
                        label: const Text(
                          'RESET',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _submitAndPrint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'SUBMIT & PRINT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function()? onTap,
    void Function()? onEditingComplete,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.blue[700],
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}