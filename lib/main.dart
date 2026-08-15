import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SVTApp());
}

class SVTApp extends StatelessWidget {
  const SVTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVT App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const BillingPage(),
    );
  }
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _formKey = GlobalKey<FormState>();

  final _customerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _kmController = TextEditingController();

  String _selectedCarType = 'Sedan';
  double _total = 0;

  double get _rate => _selectedCarType == 'Sedan' ? 20 : 22;

  void _calculate() {
    final km = double.tryParse(_kmController.text.trim()) ?? 0;

    setState(() {
      _total = km * _rate;
    });
  }

  String _billText() {
    final km = double.tryParse(_kmController.text.trim()) ?? 0;

    return '''
*SVT TRAVEL BILL*

Customer: ${_customerController.text}
Phone: ${_phoneController.text}
Vehicle: $_selectedCarType
Rate: ₹${_rate.toStringAsFixed(0)}/km
Pickup: ${_pickupController.text}
Drop: ${_dropController.text}
Distance: ${km.toStringAsFixed(1)} km

*Total: ₹${_total.toStringAsFixed(2)}*

Thank you for choosing SVT.
''';
  }

  Future<void> _sendWhatsAppMessage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _calculate();

    final phone =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(_billText())}',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp തുറക്കാൻ കഴിഞ്ഞില്ല.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _phoneController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVT Travel Bill'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(
                Icons.directions_car,
                size: 64,
              ),

              const SizedBox(height: 8),

              const Text(
                'Car Rental / Taxi Billing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'കസ്റ്റമറുടെ പേര്',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'പേര് നൽകുക';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp നമ്പർ',
                  hintText: '91XXXXXXXXXX',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'ശരിയായ നമ്പർ നൽകുക';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedCarType,
                decoration: const InputDecoration(
                  labelText: 'കാറിന്റെ തരം',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sedan',
                    child: Text('Sedan (₹20/km)'),
                  ),
                  DropdownMenuItem(
                    value: 'SUV',
                    child: Text('SUV (₹22/km)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCarType = value;
                    });
                    _calculate();
                  }
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  labelText: 'Pickup സ്ഥലം',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pickup നൽകുക';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _dropController,
                decoration: const InputDecoration(
                  labelText: 'Drop സ്ഥലം',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Drop നൽകുക';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _kmController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ആകെ കിലോമീറ്റർ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculate(),
                validator: (value) {
                  final km = double.tryParse(value?.trim() ?? '');

                  if (km == null || km <= 0) {
                    return 'കിലോമീറ്റർ നൽകുക';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ആകെ ബിൽ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('ബിൽ കണക്കാക്കുക'),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendWhatsAppMessage,
                  icon: const Icon(
                    Icons.chat,
                    color: Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                  label: const Text(
                    'വാട്‌സാപ്പ് വഴി ബിൽ അയക്കുക',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
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
