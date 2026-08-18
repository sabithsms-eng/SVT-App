import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

const googleReviewUrl = 'https://maps.app.goo.gl/wKGTJt8RZ7QqJqSu6';
final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  runApp(const SVTApp());
}

class Booking {
  String id, guest, phone, vehicle, driver, details, billingType, vehicleType;
  DateTime startDate, closeDate;
  double startKm, closeKm, toll, parking, total;

  Booking({
    required this.id,
    required this.guest,
    required this.phone,
    required this.vehicle,
    required this.driver,
    required this.details,
    required this.startDate,
    required this.closeDate,
    required this.startKm,
    required this.closeKm,
    required this.toll,
    required this.parking,
    required this.billingType,
    required this.vehicleType,
    required this.total,
  });

  double get totalKm => (closeKm - startKm).clamp(0, double.infinity);
  int get days => closeDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'guest': guest,
        'phone': phone,
        'vehicle': vehicle,
        'driver': driver,
        'details': details,
        'startDate': startDate.toIso8601String(),
        'closeDate': closeDate.toIso8601String(),
        'startKm': startKm,
        'closeKm': closeKm,
        'toll': toll,
        'parking': parking,
        'billingType': billingType,
        'vehicleType': vehicleType,
        'total': total,
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'],
        guest: j['guest'] ?? '',
        phone: j['phone'] ?? '',
        vehicle: j['vehicle'] ?? '',
        driver: j['driver'] ?? '',
        details: j['details'] ?? '',
        startDate: DateTime.parse(j['startDate']),
        closeDate: DateTime.parse(j['closeDate']),
        startKm: (j['startKm'] ?? 0).toDouble(),
        closeKm: (j['closeKm'] ?? 0).toDouble(),
        toll: (j['toll'] ?? 0).toDouble(),
        parking: (j['parking'] ?? 0).toDouble(),
        billingType: j['billingType'] ?? 'KM Based',
        vehicleType: j['vehicleType'] ?? 'Sedan',
        total: (j['total'] ?? 0).toDouble(),
      );
}

class PreBooking {
  String id, guest, phone, vehicle, details;
  DateTime requiredDate;

  PreBooking({
    required this.id,
    required this.guest,
    required this.phone,
    required this.vehicle,
    required this.requiredDate,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'guest': guest,
        'phone': phone,
        'vehicle': vehicle,
        'requiredDate': requiredDate.toIso8601String(),
        'details': details,
      };

  factory PreBooking.fromJson(Map<String, dynamic> j) => PreBooking(
        id: j['id'],
        guest: j['guest'] ?? '',
        phone: j['phone'] ?? '',
        vehicle: j['vehicle'] ?? '',
        requiredDate: DateTime.parse(j['requiredDate']),
        details: j['details'] ?? '',
      );
}

Future<void> scheduleReminder(PreBooking b) async {
  final d = DateTime(
    b.requiredDate.year,
    b.requiredDate.month,
    b.requiredDate.day,
    9,
  ).subtract(const Duration(days: 1));

  if (d.isBefore(DateTime.now())) return;

  await notifications.zonedSchedule(
    b.id.hashCode,
    'SVT Vehicle Booking Reminder',
    '${b.guest} • Vehicle required ${DateFormat('dd/MM/yyyy').format(b.requiredDate)}',
    tz.TZDateTime.from(d, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'svt_booking',
        'SVT Booking Reminders',
        channelDescription: 'Upcoming vehicle booking reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

class SVTApp extends StatelessWidget {
  const SVTApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SVT Tours & Transport',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  final bookings = <Booking>[];
  final preBookings = <PreBooking>[];

  double kmRate = 20;
  double sedanRate = 3500;
  double suvRate = 4500;
  double includedKm = 100;
  double extraKmRate = 20;
  String officeWhatsApp = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      bookings
        ..clear()
        ..addAll((p.getStringList('bookings') ?? [])
            .map((e) => Booking.fromJson(jsonDecode(e))));
      preBookings
        ..clear()
        ..addAll((p.getStringList('prebookings') ?? [])
            .map((e) => PreBooking.fromJson(jsonDecode(e))));
      kmRate = p.getDouble('kmRate') ?? 20;
      sedanRate = p.getDouble('sedanRate') ?? 3500;
      suvRate = p.getDouble('suvRate') ?? 4500;
      includedKm = p.getDouble('includedKm') ?? 100;
      extraKmRate = p.getDouble('extraKmRate') ?? 20;
      officeWhatsApp = p.getString('officeWhatsApp') ?? '';
    });
  }

  Future<void> saveData() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'bookings', bookings.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('prebookings',
        preBookings.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> openSettings() async {
    final c = [
      TextEditingController(text: '$kmRate'),
      TextEditingController(text: '$sedanRate'),
      TextEditingController(text: '$suvRate'),
      TextEditingController(text: '$includedKm'),
      TextEditingController(text: '$extraKmRate'),
      TextEditingController(text: officeWhatsApp),
    ];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Internal Settings'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              setting('KM Rate', c[0]),
              setting('Sedan Full Day Rate', c[1]),
              setting('SUV Full Day Rate', c[2]),
              setting('Included KM / Day', c[3]),
              setting('Extra KM Rate', c[4]),
              setting('Office WhatsApp Number', c[5],
                  type: TextInputType.phone),
              const SizedBox(height: 8),
              const Text(
                'Rates are internal only and are never printed on the guest bill.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              setState(() {
                kmRate = double.tryParse(c[0].text) ?? kmRate;
                sedanRate = double.tryParse(c[1].text) ?? sedanRate;
                suvRate = double.tryParse(c[2].text) ?? suvRate;
                includedKm = double.tryParse(c[3].text) ?? includedKm;
                extraKmRate = double.tryParse(c[4].text) ?? extraKmRate;
                officeWhatsApp = c[5].text.trim();
              });
              await p.setDouble('kmRate', kmRate);
              await p.setDouble('sedanRate', sedanRate);
              await p.setDouble('suvRate', suvRate);
              await p.setDouble('includedKm', includedKm);
              await p.setDouble('extraKmRate', extraKmRate);
              await p.setString('officeWhatsApp', officeWhatsApp);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget setting(String label, TextEditingController c,
      {TextInputType type = TextInputType.number}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('SVT Tours & Transport'),
          actions: [
            IconButton(
              tooltip: 'Google Review',
              onPressed: () => launchUrl(Uri.parse(googleReviewUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.star),
            ),
            IconButton(
                onPressed: openSettings, icon: const Icon(Icons.settings)),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: [
            BillPage(
              kmRate: kmRate,
              sedanRate: sedanRate,
              suvRate: suvRate,
              includedKm: includedKm,
              extraKmRate: extraKmRate,
              onSaved: (b) async {
                bookings.insert(0, b);
                await saveData();
                setState(() {});
              },
            ),
            HistoryPage(bookings: bookings),
            PreBookingPage(
              preBookings: preBookings,
              officeWhatsApp: officeWhatsApp,
              onSaved: (b) async {
                preBookings.insert(0, b);
                await saveData();
                await scheduleReminder(b);
                setState(() {});
              },
              onDelete: (b) async {
                preBookings.removeWhere((x) => x.id == b.id);
                await saveData();
                await notifications.cancel(b.id.hashCode);
                setState(() {});
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.receipt_long), label: 'New Bill'),
            NavigationDestination(
                icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(
                icon: Icon(Icons.event_available), label: 'Pre-Booking'),
          ],
        ),
      );
}

class BillPage extends StatefulWidget {
  final double kmRate, sedanRate, suvRate, includedKm, extraKmRate;
  final Future<void> Function(Booking) onSaved;

  const BillPage({
    super.key,
    required this.kmRate,
    required this.sedanRate,
    required this.suvRate,
    required this.includedKm,
    required this.extraKmRate,
    required this.onSaved,
  });

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  final form = GlobalKey<FormState>();
  final guest = TextEditingController();
  final phone = TextEditingController();
  final vehicle = TextEditingController();
  final driver = TextEditingController();
  final details = TextEditingController();
  final startKm = TextEditingController();
  final closeKm = TextEditingController();
  final toll = TextEditingController(text: '0');
  final parking = TextEditingController(text: '0');

  DateTime startDate = DateTime.now();
  DateTime closeDate = DateTime.now();
  String billing = 'KM Based';
  String vehicleType = 'Sedan';

  double n(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get totalKm => (n(closeKm) - n(startKm)).clamp(0, double.infinity);
  int get days => closeDate.difference(startDate).inDays + 1;

  double get total {
    if (billing == 'KM Based') {
      return totalKm * widget.kmRate + n(toll) + n(parking);
    }
    final base = vehicleType == 'SUV' ? widget.suvRate : widget.sedanRate;
    final extra = (totalKm - widget.includedKm * days).clamp(0, double.infinity);
    return base * days + extra * widget.extraKmRate + n(toll) + n(parking);
  }

  String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> chooseDate(bool start) async {
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

  Booking makeBooking() => Booking(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        guest: guest.text.trim(),
        phone: phone.text.trim(),
        vehicle: vehicle.text.trim(),
        driver: driver.text.trim(),
        details: details.text.trim(),
        startDate: startDate,
        closeDate: closeDate,
        startKm: n(startKm),
        closeKm: n(closeKm),
        toll: n(toll),
        parking: n(parking),
        billingType: billing,
        vehicleType: vehicleType,
        total: total,
      );

  Future<Uint8List> pdfBytes(Booking b) async {
    final doc = pw.Document();

    pw.Widget row(String a, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(a,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(child: pw.Text(v)),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SVT TOURS & TRANSPORT',
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text('TRIP BILL'),
            pw.Divider(),
            row('Bill Date', date(DateTime.now())),
            row('Guest', b.guest),
            row('Phone', b.phone),
            row('Vehicle Number', b.vehicle),
            if (b.driver.isNotEmpty) row('Driver', b.driver),
            row('Starting Date', date(b.startDate)),
            row('Closing Date', date(b.closeDate)),
            row('Total Days', '${b.days}'),
            row('Starting KM', b.startKm.toStringAsFixed(0)),
            row('Closing KM', b.closeKm.toStringAsFixed(0)),
            row('Total KM', b.totalKm.toStringAsFixed(0)),
            row(
              'Trip Type',
              b.billingType == 'Full Day'
                  ? 'Full Day (${b.vehicleType})'
                  : 'KM Based',
            ),
            if (b.details.isNotEmpty) row('Trip Details', b.details),
            if (b.toll > 0) row('Toll', 'Rs ${b.toll.toStringAsFixed(2)}'),
            if (b.parking > 0)
              row('Parking', 'Rs ${b.parking.toStringAsFixed(2)}'),
            pw.SizedBox(height: 14),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTAL: Rs ${b.total.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Spacer(),
            pw.Center(
                child:
                    pw.Text('Thank you for choosing SVT Tours & Transport!')),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> sharePdf(Booking b) async {
    final bytes = await pdfBytes(b);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SVT_${b.id}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'SVT Tours & Transport bill for ${b.guest}',
    );
  }

  Future<void> whatsappText(Booking b) async {
    final text = '''SVT TOURS & TRANSPORT
Trip Bill

Guest: ${b.guest}
Vehicle: ${b.vehicle}
Starting Date: ${date(b.startDate)}
Closing Date: ${date(b.closeDate)}
Total Days: ${b.days}
Total KM: ${b.totalKm.toStringAsFixed(0)}
Total Amount: Rs ${b.total.toStringAsFixed(2)}

Thank you for choosing SVT Tours & Transport!''';

    final number = b.phone.replaceAll(RegExp(r'[^0-9]'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> saveBooking() async {
    if (!form.currentState!.validate()) return;
    await widget.onSaved(makeBooking());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking saved successfully')),
      );
    }
  }

  void clear() {
    for (final c in [
      guest,
      phone,
      vehicle,
      driver,
      details,
      startKm,
      closeKm
    ]) {
      c.clear();
    }
    toll.text = '0';
    parking.text = '0';
    setState(() {
      startDate = DateTime.now();
      closeDate = DateTime.now();
      billing = 'KM Based';
      vehicleType = 'Sedan';
    });
  }

  Widget field(String label, TextEditingController c,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            field('Guest Name', guest, required: true),
            field('Guest Phone', phone,
                required: true, type: TextInputType.phone),
            field('Vehicle Number', vehicle, required: true),
            DropdownButtonFormField<String>(
              value: billing,
              decoration: const InputDecoration(labelText: 'Billing Type'),
              items: const [
                DropdownMenuItem(value: 'KM Based', child: Text('KM Based')),
                DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
              ],
              onChanged: (v) => setState(() => billing = v!),
            ),
            if (billing == 'Full Day') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: vehicleType,
                decoration: const InputDecoration(labelText: 'Vehicle Type'),
                items: const [
                  DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                  DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                ],
                onChanged: (v) => setState(() => vehicleType = v!),
              ),
            ],
            const SizedBox(height: 10),
            field('Starting KM', startKm, type: TextInputType.number),
            field('Closing KM', closeKm, type: TextInputType.number),
            Text('Total KM: ${totalKm.toStringAsFixed(0)}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Starting Date: ${date(startDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => chooseDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Closing Date: ${date(closeDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => chooseDate(false),
            ),
            Text('Total Days: $days'),
            const SizedBox(height: 10),
            field('Driver Name (Optional)', driver),
            field('Details of Trip (Optional)', details),
            field('Toll Amount (Optional)', toll,
                type: TextInputType.number),
            field('Parking Amount (Optional)', parking,
                type: TextInputType.number),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Total Amount: Rs ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saveBooking,
              icon: const Icon(Icons.save),
              label: const Text('Save Booking'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                await sharePdf(makeBooking());
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF → WhatsApp / Share'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                await whatsappText(makeBooking());
              },
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp Text Bill'),
            ),
            TextButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Form'),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    for (final c in [
      guest,
      phone,
      vehicle,
      driver,
      details,
      startKm,
      closeKm,
      toll,
      parking
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}

class HistoryPage extends StatefulWidget {
  final List<Booking> bookings;
  const HistoryPage({super.key, required this.bookings});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? from, to;

  List<Booking> get filtered => widget.bookings.where((b) {
        if (from != null && b.startDate.isBefore(from!)) return false;
        if (to != null &&
            b.startDate.isAfter(
                DateTime(to!.year, to!.month, to!.day, 23, 59, 59))) {
          return false;
        }
        return true;
      }).toList();

  Future<void> pick(bool isFrom) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => isFrom ? from = d : to = d);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => pick(true),
                    icon: const Icon(Icons.date_range),
                    label: Text(from == null
                        ? 'From Date'
                        : DateFormat('dd/MM/yyyy').format(from!)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.date_range),
                    label: Text(to == null
                        ? 'To Date'
                        : DateFormat('dd/MM/yyyy').format(to!)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      from = null;
                      to = null;
                    }),
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No bookings found'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: ListTile(
                          title: Text(b.guest),
                          subtitle: Text(
                              '${DateFormat('dd/MM/yyyy').format(b.startDate)} • ${b.vehicle} • ${b.totalKm.toStringAsFixed(0)} KM'),
                          trailing: Text('Rs ${b.total.toStringAsFixed(0)}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
}

class PreBookingPage extends StatefulWidget {
  final List<PreBooking> preBookings;
  final String officeWhatsApp;
  final Future<void> Function(PreBooking) onSaved;
  final Future<void> Function(PreBooking) onDelete;

  const PreBookingPage({
    super.key,
    required this.preBookings,
    required this.officeWhatsApp,
    required this.onSaved,
    required this.onDelete,
  });

  @override
  State<PreBookingPage> createState() => _PreBookingPageState();
}

class _PreBookingPageState extends State<PreBookingPage> {
  final form = GlobalKey<FormState>();
  final guest = TextEditingController();
  final phone = TextEditingController();
  final vehicle = TextEditingController();
  final details = TextEditingController();
  DateTime requiredDate = DateTime.now().add(const Duration(days: 1));

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: requiredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => requiredDate = d);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;

    final b = PreBooking(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      guest: guest.text.trim(),
      phone: phone.text.trim(),
      vehicle: vehicle.text.trim(),
      requiredDate: requiredDate,
      details: details.text.trim(),
    );

    await widget.onSaved(b);
    clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Pre-booking saved. Reminder set for one day before.')),
      );
    }
  }

  Future<void> sendRequirement(PreBooking b) async {
    final number = (widget.officeWhatsApp.isNotEmpty
            ? widget.officeWhatsApp
            : b.phone)
        .replaceAll(RegExp(r'[^0-9]'), '');

    final text = '''SVT PRE-BOOKING REQUIREMENT
Guest: ${b.guest}
Guest Phone: ${b.phone}
Vehicle / Requirement: ${b.vehicle}
Vehicle Required Date: ${DateFormat('dd/MM/yyyy').format(b.requiredDate)}
Details: ${b.details}''';

    await launchUrl(
      Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void clear() {
    guest.clear();
    phone.clear();
    vehicle.clear();
    details.clear();
    setState(() {
      requiredDate = DateTime.now().add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pre-Booking',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: guest,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Guest Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Guest Phone'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: vehicle,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle / Requirement'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Vehicle Required Date: ${DateFormat('dd/MM/yyyy').format(requiredDate)}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: pickDate,
                ),
                TextFormField(
                  controller: details,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Details (Optional)'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Save + Reminder'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...widget.preBookings.map(
            (b) => Card(
              child: ListTile(
                title: Text(b.guest),
                subtitle: Text(
                    '${b.vehicle} • ${DateFormat('dd/MM/yyyy').format(b.requiredDate)}'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'WhatsApp requirement',
                      onPressed: () => sendRequirement(b),
                      icon: const Icon(Icons.chat),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => widget.onDelete(b),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  @override
  void dispose() {
    guest.dispose();
    phone.dispose();
    vehicle.dispose();
    details.dispose();
    super.dispose();
  }
}
