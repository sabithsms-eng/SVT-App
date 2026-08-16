import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const SVTApp());

class SVTApp extends StatelessWidget {
  const SVTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVT Tours and Transport',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const BillingPage(),
    );
  }
}

class Booking {
  final String id;
  final DateTime date;
  final String customer;
  final String phone;
  final String vehicle;
  final String pickup;
  final String drop;
  final double km;
  final double kmRate;
  final double toll;
  final double parking;
  final double total;

  const Booking({
    required this.id,
    required this.date,
    required this.customer,
    required this.phone,
    required this.vehicle,
    required this.pickup,
    required this.drop,
    required this.km,
    required this.kmRate,
    required this.toll,
    required this.parking,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'customer': customer,
        'phone': phone,
        'vehicle': vehicle,
        'pickup': pickup,
        'drop': drop,
        'km': km,
        'kmRate': kmRate,
        'toll': toll,
        'parking': parking,
        'total': total,
      };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        customer: json['customer'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        pickup: json['pickup'] as String? ?? '',
        drop: json['drop'] as String? ?? '',
        km: (json['km'] as num?)?.toDouble() ?? 0,
        kmRate: (json['kmRate'] as num?)?.toDouble() ?? 0,
        toll: (json['toll'] as num?)?.toDouble() ?? 0,
        parking: (json['parking'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
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
  final _tollController = TextEditingController();
  final _parkingController = TextEditingController();
  final _sedanRateController = TextEditingController();
  final _suvRateController = TextEditingController();

  String _selectedCarType = 'Sedan';
  DateTime _selectedDate = DateTime.now();
  double _total = 0;
  List<Booking> _bookings = [];
  bool _loading = true;

  double get _rate => _selectedCarType == 'Sedan'
      ? (double.tryParse(_sedanRateController.text) ?? 0)
      : (double.tryParse(_suvRateController.text) ?? 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('bookings');
    final sedan = prefs.getDouble('sedan_rate') ?? 20;
    final suv = prefs.getDouble('suv_rate') ?? 22;
    final list = <Booking>[];

    if (saved != null && saved.isNotEmpty) {
      final raw = jsonDecode(saved) as List<dynamic>;
      for (final item in raw) {
        list.add(Booking.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    if (!mounted) return;
    setState(() {
      _sedanRateController.text = sedan.toString();
      _suvRateController.text = suv.toString();
      _bookings = list;
      _loading = false;
    });
    _calculate();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      'sedan_rate',
      double.tryParse(_sedanRateController.text) ?? 20,
    );
    await prefs.setDouble(
      'suv_rate',
      double.tryParse(_suvRateController.text) ?? 22,
    );
    await prefs.setString(
      'bookings',
      jsonEncode(_bookings.map((e) => e.toJson()).toList()),
    );
  }

  void _calculate() {
    final km = double.tryParse(_kmController.text.trim()) ?? 0;
    final toll = double.tryParse(_tollController.text.trim()) ?? 0;
    final parking = double.tryParse(_parkingController.text.trim()) ?? 0;
    setState(() => _total = km * _rate + toll + parking);
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
    _calculate();

    final booking = Booking(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      customer: _customerController.text.trim(),
      phone: _phoneController.text.trim(),
      vehicle: _selectedCarType,
      pickup: _pickupController.text.trim(),
      drop: _dropController.text.trim(),
      km: double.tryParse(_kmController.text.trim()) ?? 0,
      kmRate: _rate,
      toll: double.tryParse(_tollController.text.trim()) ?? 0,
      parking: double.tryParse(_parkingController.text.trim()) ?? 0,
      total: _total,
    );

    setState(() => _bookings = [booking, ..._bookings]);
    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking / Bill saved successfully.')),
      );
    }
  }

  String _billText() {
    final km = double.tryParse(_kmController.text.trim()) ?? 0;
    final toll = double.tryParse(_tollController.text.trim()) ?? 0;
    final parking = double.tryParse(_parkingController.text.trim()) ?? 0;
    final extras = <String>[];
    if (toll > 0) extras.add('Toll: ₹${toll.toStringAsFixed(2)}');
    if (parking > 0) extras.add('Parking: ₹${parking.toStringAsFixed(2)}');

    return '''
*SVT TOURS AND TRANSPORT*

Date: ${_date(_selectedDate)}
Customer: ${_customerController.text}
Phone: ${_phoneController.text}
Vehicle: $_selectedCarType
Pickup: ${_pickupController.text}
Drop: ${_dropController.text}
Distance: ${km.toStringAsFixed(1)} km
${extras.isEmpty ? '' : '${extras.join('\n')}\n'}
*Total Amount: ₹${_total.toStringAsFixed(2)}*

Thank you for choosing SVT Tours and Transport.
We appreciate your valuable support.

⭐ Please review us on Google:
https://maps.app.goo.gl/wKGTJt8RZ7QqJqSu6
''';
  }

  Future<void> _whatsapp() async {
    if (!_formKey.currentState!.validate()) return;
    _calculate();
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(_billText())}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp തുറക്കാൻ കഴിഞ്ഞില്ല.')),
      );
    }
  }

  Future<void> _review() async {
    final uri = Uri.parse('https://maps.app.goo.gl/wKGTJt8RZ7QqJqSu6');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Review page തുറക്കാൻ കഴിഞ്ഞില്ല.')),
      );
    }
  }

  Future<void> _rates() async {
    final sedan = TextEditingController(text: _sedanRateController.text);
    final suv = TextEditingController(text: _suvRateController.text);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('KM Rate Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sedan,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sedan Rate / KM',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: suv,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'SUV Rate / KM',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final a = double.tryParse(sedan.text);
              final b = double.tryParse(suv.text);
              if (a == null || b == null || a < 0 || b < 0) return;
              _sedanRateController.text = a.toString();
              _suvRateController.text = b.toString();
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    sedan.dispose();
    suv.dispose();

    if (ok == true) {
      await _saveData();
      _calculate();
    }
  }

  Future<void> _history() async {
    DateTime? from;
    DateTime? to;
    List<Booking> filtered = List.of(_bookings);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          void filter() {
            filtered = _bookings.where((b) {
              final d = DateTime(b.date.year, b.date.month, b.date.day);
              final f = from == null ||
                  !d.isBefore(DateTime(from!.year, from!.month, from!.day));
              final t = to == null ||
                  !d.isAfter(DateTime(to!.year, to!.month, to!.day));
              return f && t;
            }).toList();
            setDialogState(() {});
          }

          Future<void> chooseFrom() async {
            final d = await showDatePicker(
              context: context,
              initialDate: from ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              from = d;
              filter();
            }
          }

          Future<void> chooseTo() async {
            final d = await showDatePicker(
              context: context,
              initialDate: to ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              to = d;
              filter();
            }
          }

          return AlertDialog(
            title: const Text('Customer / Booking History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 430,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: chooseFrom,
                          child: Text(from == null ? 'From date' : _date(from!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: chooseTo,
                          child: Text(to == null ? 'To date' : _date(to!)),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      from = null;
                      to = null;
                      filter();
                    },
                    child: const Text('Clear filter'),
                  ),
                  const Divider(),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No bookings found.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final b = filtered[i];
                              return ListTile(
                                title: Text(b.customer),
                                subtitle: Text(
                                  '${_date(b.date)} • ${b.vehicle} • ${b.km.toStringAsFixed(1)} km',
                                ),
                                trailing: Text(
                                  '₹${b.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clear() {
    _customerController.clear();
    _phoneController.clear();
    _pickupController.clear();
    _dropController.clear();
    _kmController.clear();
    _tollController.clear();
    _parkingController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCarType = 'Sedan';
      _total = 0;
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _phoneController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _kmController.dispose();
    _tollController.dispose();
    _parkingController.dispose();
    _sedanRateController.dispose();
    _suvRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SVT Tours and Transport'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _rates, icon: const Icon(Icons.settings)),
          IconButton(onPressed: _history, icon: const Icon(Icons.history)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.directions_car, size: 64),
              const SizedBox(height: 8),
              const Text(
                'Car Rental / Taxi Billing',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text('Date: ${_date(_selectedDate)}'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'കസ്റ്റമറുടെ പേര്',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'പേര് നൽകുക' : null,
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
                validator: (v) =>
                    v == null || v.trim().length < 10 ? 'ശരിയായ നമ്പർ നൽകുക' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCarType,
                decoration: const InputDecoration(
                  labelText: 'കാറിന്റെ തരം',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                  DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedCarType = v);
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Pickup നൽകുക' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dropController,
                decoration: const InputDecoration(
                  labelText: 'Drop സ്ഥലം',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Drop നൽകുക' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _kmController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ആകെ കിലോമീറ്റർ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculate(),
                validator: (v) {
                  final km = double.tryParse(v?.trim() ?? '');
                  return km == null || km <= 0 ? 'കിലോമീറ്റർ നൽകുക' : null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tollController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Toll Amount (Optional)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculate(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _parkingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Parking Amount (Optional)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculate(),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveBooking,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Booking / Bill'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: const Text(
                    'വാട്‌സാപ്പ് വഴി ബിൽ അയക്കുക',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.star),
                  label: const Text('Review us on Google'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _history,
                icon: const Icon(Icons.history),
                label: const Text('Customer / Booking History'),
              ),
              TextButton(
                onPressed: _clear,
                child: const Text('Clear Form'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
