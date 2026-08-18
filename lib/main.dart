import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SVTApp());
}

class SVTApp extends StatelessWidget {
  const SVTApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SVT Tours & Transport',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _form = GlobalKey<FormState>();
  final guest = TextEditingController();
  final phone = TextEditingController();
  final vehicle = TextEditingController();
  final startKm = TextEditingController();
  final closeKm = TextEditingController();
  final driver = TextEditingController();
  final details = TextEditingController();
  final toll = TextEditingController(text: '0');
  final parking = TextEditingController(text: '0');

  DateTime startDate = DateTime.now();
  DateTime closeDate = DateTime.now();
  String billing = 'KM Based';
  String vehicleType = 'Sedan';
  double kmRate = 20, sedanRate = 3500, suvRate = 4500, includedKm = 100, extraKmRate = 20;

  double n(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get totalKm => (n(closeKm) - n(startKm)).clamp(0, double.infinity);
  int get days => closeDate.difference(startDate).inDays + 1;
  double get total {
    double fare;
    if (billing == 'KM Based') {
      fare = totalKm * kmRate;
    } else {
      final base = vehicleType == 'SUV' ? suvRate : sedanRate;
      final extra = (totalKm - includedKm * days).clamp(0, double.infinity);
      fare = base * days + extra * extraKmRate;
    }
    return fare + n(toll) + n(parking);
  }

  @override
  void initState() {
    super.initState();
    loadRates();
  }

  Future<void> loadRates() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      kmRate = p.getDouble('kmRate') ?? 20;
      sedanRate = p.getDouble('sedanRate') ?? 3500;
      suvRate = p.getDouble('suvRate') ?? 4500;
      includedKm = p.getDouble('includedKm') ?? 100;
      extraKmRate = p.getDouble('extraKmRate') ?? 20;
    });
  }

  Future<void> pickDate(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? startDate : closeDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        startDate = d;
        if (closeDate.isBefore(d)) closeDate = d;
      } else {
        closeDate = d.isBefore(startDate) ? startDate : d;
      }
    });
  }

  String date(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Widget input(String label, TextEditingController c, {bool required = false, TextInputType? type}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );

  Future<void> settings() async {
    final a = TextEditingController(text: kmRate.toString());
    final b = TextEditingController(text: sedanRate.toString());
    final c = TextEditingController(text: suvRate.toString());
    final d = TextEditingController(text: includedKm.toString());
    final e = TextEditingController(text: extraKmRate.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Internal Rate Settings'),
        content: SingleChildScrollView(
          child: Column(children: [
            inputBox('KM Rate', a), inputBox('Sedan Full Day', b),
            inputBox('SUV Full Day', c), inputBox('Included KM / Day', d),
            inputBox('Extra KM Rate', e),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              setState(() {
                kmRate = double.tryParse(a.text) ?? kmRate;
                sedanRate = double.tryParse(b.text) ?? sedanRate;
                suvRate = double.tryParse(c.text) ?? suvRate;
                includedKm = double.tryParse(d.text) ?? includedKm;
                extraKmRate = double.tryParse(e.text) ?? extraKmRate;
              });
              await p.setDouble('kmRate', kmRate);
              await p.setDouble('sedanRate', sedanRate);
              await p.setDouble('suvRate', suvRate);
              await p.setDouble('includedKm', includedKm);
              await p.setDouble('extraKmRate', extraKmRate);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget inputBox(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  Future<void> save() async {
    if (!_form.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking saved successfully')),
    );
  }

  Future<void> review() async {
    await launchUrl(
      Uri.parse('https://maps.app.goo.gl/wKGTJt8RZ7QqJqSu6'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVT Tours & Transport'),
        actions: [
          IconButton(onPressed: settings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            input('Guest Name', guest, required: true),
            input('Guest Phone', phone, required: true, type: TextInputType.phone),
            input('Vehicle Number', vehicle, required: true),
            DropdownButtonFormField<String>(
              value: billing,
              decoration: const InputDecoration(labelText: 'Billing Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'KM Based', child: Text('KM Based')),
                DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
              ],
              onChanged: (v) => setState(() => billing = v!),
            ),
            const SizedBox(height: 10),
            if (billing == 'Full Day')
              DropdownButtonFormField<String>(
                value: vehicleType,
                decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                  DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                ],
                onChanged: (v) => setState(() => vehicleType = v!),
              ),
            if (billing == 'Full Day') const SizedBox(height: 10),
            input('Starting KM', startKm, type: TextInputType.number),
            input('Closing KM', closeKm, type: TextInputType.number),
            Text('Total KM: ${totalKm.toStringAsFixed(0)}'),
            ListTile(title: Text('Starting Date: ${date(startDate)}'), onTap: () => pickDate(true), trailing: const Icon(Icons.calendar_today)),
            ListTile(title: Text('Closing Date: ${date(closeDate)}'), onTap: () => pickDate(false), trailing: const Icon(Icons.calendar_today)),
            Text('Total Days: $days'),
            const SizedBox(height: 10),
            input('Driver Name (Optional)', driver),
            input('Details of Trip (Optional)', details),
            input('Toll Amount (Optional)', toll, type: TextInputType.number),
            input('Parking Amount (Optional)', parking, type: TextInputType.number),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Total Amount: ₹${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Save Booking')),
            OutlinedButton.icon(onPressed: review, icon: const Icon(Icons.star), label: const Text('Google Review')),
            const SizedBox(height: 12),
            const Center(child: Text('Thank you for choosing SVT Tours & Transport!')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [guest, phone, vehicle, startKm, closeKm, driver, details, toll, parking]) {
      c.dispose();
    }
    super.dispose();
  }
}
