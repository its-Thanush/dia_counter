import 'package:dia_counter/customtext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Mainscreen extends StatefulWidget {
  const Mainscreen({super.key});

  @override
  State<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends State<Mainscreen> {
  final TextEditingController qrController = TextEditingController();
  final TextEditingController actualSectionController = TextEditingController();
  final TextEditingController setPointController = TextEditingController();
  final TextEditingController spSectionController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    actualSectionController.text = '0000.00';
    setPointController.text = '0000.00';
  }

  @override
  void dispose() {
    qrController.dispose();
    actualSectionController.dispose();
    setPointController.dispose();
    spSectionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      qrController.clear();
      actualSectionController.text = '0000.00';
      setPointController.text = '0000.00';
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

    // Limit to 4 digits before decimal and 2 after
    if (formatted.contains('.')) {
      List<String> parts = formatted.split('.');
      String integerPart = parts[0].substring(0, parts[0].length > 4 ? 4 : parts[0].length);
      String decimalPart = parts.length > 1 ? parts[1].substring(0, parts[1].length > 2 ? 2 : parts[1].length) : '';
      formatted = '$integerPart.$decimalPart';
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
        title:  Text(
          "DIA COUNTER",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // QR Code Field
                _buildLabel("QR Code"),
                const SizedBox(height: 8),
                CustomText(text: "58746541985151",),
                // _buildTextField(
                //   controller: qrController,
                //   hintText: "Enter QR Code",
                //   prefixIcon: Icons.qr_code_2,
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please enter QR code';
                //     }
                //     return null;
                //   },
                // ),+

                 SizedBox(height: 24),

                _buildLabel("Actual Section"),
                const SizedBox(height: 8),
                CustomText(text: "45582.00",),
                // _buildTextField(
                //   controller: actualSectionController,
                //   hintText: "0000.00",
                //   prefixIcon: Icons.straighten,
                //   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                //   onChanged: (value) => _formatFloatOnChange(actualSectionController, value),
                //   onTap: () {
                //     if (actualSectionController.text == '0000.00') {
                //       actualSectionController.clear();
                //     }
                //   },
                //   onEditingComplete: () {
                //     _formatFloatOnBlur(actualSectionController);
                //     FocusScope.of(context).nextFocus();
                //   },
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please enter actual section';
                //     }
                //     return null;
                //   },
                // ),

                const SizedBox(height: 24),

                // Set Point Field
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

                const SizedBox(height: 24),

                // SP Section Field
                _buildLabel("SP Section (0-9)"),
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

                const SizedBox(height: 40),

                // Reset Button
                Center(
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

                const SizedBox(height: 24),

                // // Submit Button (optional)
                // SizedBox(
                //   width: double.infinity,
                //   child: ElevatedButton(
                //     onPressed: () {
                //       if (_formKey.currentState!.validate()) {
                //         // Process the data
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           SnackBar(
                //             content: Text(
                //               'QR: ${qrController.text}\n'
                //                   'Actual: ${actualSectionController.text}\n'
                //                   'Set Point: ${setPointController.text}\n'
                //                   'SP Section: ${spSectionController.text}',
                //             ),
                //             duration: const Duration(seconds: 3),
                //             backgroundColor: Colors.blue[700],
                //           ),
                //         );
                //       }
                //     },
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.blue[700],
                //       foregroundColor: Colors.white,
                //       padding: const EdgeInsets.symmetric(vertical: 16),
                //       elevation: 2,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(12),
                //       ),
                //     ),
                //     child: const Text(
                //       'SUBMIT',
                //       style: TextStyle(
                //         fontSize: 16,
                //         fontWeight: FontWeight.bold,
                //         letterSpacing: 1.2,
                //       ),
                //     ),
                //   ),
                // ),

                const SizedBox(height: 20),
              ],
            ),
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