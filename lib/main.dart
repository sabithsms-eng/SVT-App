import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';
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

Future<Map<Object?, Object?>?> pickNativeContact(BuildContext context) async {
  final permitted = await FlutterContacts.requestPermission(readonly: true);
  if (!permitted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Contacts permission denied. Enter the phone manually.')));
    }
    return null;
  }
  return const MethodChannel('svt/contact_picker')
      .invokeMethod<Map<Object?, Object?>>('pickContact');
}

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
  DateTime startDate, closeDate, startTime, closeTime;
  double startKm, closeKm, totalKmValue, toll, parking, total;
  double extraHourCharge;

  Booking({
    required this.id,
    required this.guest,
    required this.phone,
    required this.vehicle,
    required this.driver,
    required this.details,
    required this.startDate,
    required this.closeDate,
    required this.startTime,
    required this.closeTime,
    required this.startKm,
    required this.closeKm,
    required this.totalKmValue,
    required this.toll,
    required this.parking,
    required this.billingType,
    required this.vehicleType,
    required this.total,
    required this.extraHourCharge,
  });

  double get totalKm => totalKmValue;
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
        'startTime': startTime.toIso8601String(),
        'closeTime': closeTime.toIso8601String(),
        'startKm': startKm,
        'closeKm': closeKm,
        'totalKm': totalKmValue,
        'toll': toll,
        'parking': parking,
        'billingType': billingType,
        'vehicleType': vehicleType,
        'total': total,
        'extraHourCharge': extraHourCharge,
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
        startTime: DateTime.tryParse(j['startTime'] ?? '') ??
          DateTime.parse(j['startDate']).copyWith(hour: 9, minute: 0),
        closeTime: DateTime.tryParse(j['closeTime'] ?? '') ??
          DateTime.parse(j['closeDate']).copyWith(hour: 17, minute: 0),
        startKm: (j['startKm'] ?? 0).toDouble(),
        closeKm: (j['closeKm'] ?? 0).toDouble(),
        totalKmValue:
            (j['totalKm'] ?? ((j['closeKm'] ?? 0) - (j['startKm'] ?? 0)))
                .toDouble(),
        toll: (j['toll'] ?? 0).toDouble(),
        parking: (j['parking'] ?? 0).toDouble(),
        billingType: j['billingType'] ?? 'KM Based',
        vehicleType: j['vehicleType'] ?? 'Sedan',
        total: (j['total'] ?? 0).toDouble(),
        extraHourCharge: (j['extraHourCharge'] ?? 250).toDouble(),
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
  double extraHourRate = 250;
  String officeWhatsApp = '';
  Booking? editingBooking;

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
      extraHourRate = p.getDouble('extraHourRate') ?? 250;
      officeWhatsApp = p.getString('officeWhatsApp') ?? '';
    });
  }

  Future<void> saveData() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'bookings', bookings.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList(
        'prebookings', preBookings.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> openSettings() async {
    final c = [
      TextEditingController(text: '$kmRate'),
      TextEditingController(text: '$sedanRate'),
      TextEditingController(text: '$suvRate'),
      TextEditingController(text: '$includedKm'),
      TextEditingController(text: '$extraKmRate'),
      TextEditingController(text: '$extraHourRate'),
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
                setting('Extra Hour Charge', c[5]),
                setting('Office WhatsApp Number', c[6],
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
                extraHourRate = double.tryParse(c[5].text) ?? extraHourRate;
                officeWhatsApp = c[6].text.trim();
              });
              await p.setDouble('kmRate', kmRate);
              await p.setDouble('sedanRate', sedanRate);
              await p.setDouble('suvRate', suvRate);
              await p.setDouble('includedKm', includedKm);
              await p.setDouble('extraKmRate', extraKmRate);
              await p.setDouble('extraHourRate', extraHourRate);
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
              key: ValueKey(editingBooking?.id),
              kmRate: kmRate,
              sedanRate: sedanRate,
              suvRate: suvRate,
              includedKm: includedKm,
              extraKmRate: extraKmRate,
              extraHourRate: extraHourRate,
              editingBooking: editingBooking,
              onSaved: (b) async {
                final index = bookings.indexWhere((x) => x.id == b.id);
                if (index >= 0) {
                  bookings[index] = b;
                  editingBooking = null;
                } else {
                  bookings.insert(0, b);
                }
                await saveData();
                setState(() {});
              },
            ),
            HistoryPage(
              bookings: bookings,
              onEdit: (b) => setState(() {
                editingBooking = b;
                tab = 0;
              }),
              onDelete: (b) async {
                bookings.removeWhere((x) => x.id == b.id);
                await saveData();
                setState(() {});
              },
            ),
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
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(
                icon: Icon(Icons.event_available), label: 'Pre-Booking'),
          ],
        ),
      );
}

class BillPage extends StatefulWidget {
  final double kmRate, sedanRate, suvRate, includedKm, extraKmRate, extraHourRate;
  final Booking? editingBooking;
  final Future<void> Function(Booking) onSaved;

  const BillPage({
    super.key,
    required this.kmRate,
    required this.sedanRate,
    required this.suvRate,
    required this.includedKm,
    required this.extraKmRate,
    required this.extraHourRate,
    this.editingBooking,
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
  final totalKmController = TextEditingController();
  final toll = TextEditingController(text: '0');
  final parking = TextEditingController(text: '0');
  final extraHourCharge = TextEditingController();
  final totalAmount = TextEditingController();

  DateTime startDate = DateTime.now();
  DateTime closeDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay closeTime = const TimeOfDay(hour: 17, minute: 0);
  String billing = 'KM Based';
  String vehicleType = 'Sedan';
  bool updatingKm = false;

  @override
  void initState() {
    super.initState();
    extraHourCharge.text = '${widget.extraHourRate}';
    final b = widget.editingBooking;
    if (b == null) return;
    guest.text = b.guest;
    phone.text = b.phone;
    vehicle.text = b.vehicle;
    driver.text = b.driver;
    details.text = b.details;
    startKm.text = '${b.startKm}';
    closeKm.text = '${b.closeKm}';
    totalKmController.text = '${b.totalKm}';
    toll.text = '${b.toll}';
    parking.text = '${b.parking}';
    extraHourCharge.text = '${b.extraHourCharge}';
    totalAmount.text = '${b.total}';
    startDate = b.startDate;
    closeDate = b.closeDate;
    startTime = TimeOfDay.fromDateTime(b.startTime);
    closeTime = TimeOfDay.fromDateTime(b.closeTime);
    billing = b.billingType;
    vehicleType = b.vehicleType;
  }

  double n(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get totalKm => n(totalKmController);
  int get days => closeDate.difference(startDate).inDays + 1;
  DateTime get tripStart => DateTime(startDate.year, startDate.month,
      startDate.day, startTime.hour, startTime.minute);
  DateTime get tripClose => DateTime(closeDate.year, closeDate.month,
      closeDate.day, closeTime.hour, closeTime.minute);
  double get extraHours => ((tripClose.difference(tripStart).inMinutes - 480)
          .clamp(0, double.infinity)) /
      60;
  double get calculatedTotal {
    if (billing == 'KM Based') {
      return totalKm * widget.kmRate + n(toll) + n(parking);
    }
    final base = vehicleType == 'SUV' ? widget.suvRate : widget.sedanRate;
    final extraKm =
        (totalKm - widget.includedKm * days).clamp(0, double.infinity);
    return base * days +
        extraKm * widget.extraKmRate +
        extraHours * n(extraHourCharge) +
        n(toll) +
        n(parking);
  }

  double get total => double.tryParse(totalAmount.text) ?? calculatedTotal;

  double serviceCharges(Booking b) =>
      (b.total - b.toll - b.parking).clamp(0, double.infinity).toDouble();

  String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  String timeLabel(TimeOfDay t) => t.format(context);
  double extraHoursFor(Booking b) =>
      ((b.closeTime.difference(b.startTime).inMinutes - 480)
              .clamp(0, double.infinity)) /
          60;

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

  Future<void> chooseTime(bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? startTime : closeTime,
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        startTime = selected;
      } else {
        closeTime = selected;
      }
    });
  }

  Booking makeBooking() => Booking(
      id: widget.editingBooking?.id ??
        DateTime.now().microsecondsSinceEpoch.toString(),
        guest: guest.text.trim(),
        phone: phone.text.trim(),
        vehicle: vehicle.text.trim(),
        driver: driver.text.trim(),
        details: details.text.trim(),
        startDate: startDate,
        closeDate: closeDate,
        startTime: tripStart,
        closeTime: tripClose,
        startKm: n(startKm),
        closeKm: n(closeKm),
        totalKmValue: totalKm,
        toll: n(toll),
        parking: n(parking),
        billingType: billing,
        vehicleType: vehicleType,
        total: total,
        extraHourCharge: n(extraHourCharge),
      );

  Future<Uint8List> pdfBytes(Booking b) async {
    final doc = pw.Document();

    pw.TableRow detailRow(String label, String value) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Text(label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(7),
              child: pw.Text(value),
            ),
          ],
        );

    pw.TableRow chargeRow(String label, double value,
            {bool emphasize = false}) =>
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontWeight: emphasize
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Rs ${value.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontWeight: emphasize
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal)),
              ),
            ),
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('SVT TOURS & TRANSPORT',
                  style: pw.TextStyle(
                      fontSize: 21, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('TRIP BILL / TRIP INVOICE',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                detailRow('Bill Date', date(DateTime.now())),
                detailRow('Guest Name', b.guest),
                detailRow('Guest Phone', b.phone),
                detailRow('Vehicle Number', b.vehicle),
                detailRow('Vehicle Type', b.vehicleType),
                detailRow('Starting Date', date(b.startDate)),
                detailRow('Closing Date', date(b.closeDate)),
                if (b.billingType == 'Full Day') ...[
                  detailRow('Extra Hours',
                      '${extraHoursFor(b).toStringAsFixed(2)} Hours'),
                ],
                detailRow('Total Days', '${b.days}'),
                detailRow('Starting KM', b.startKm.toStringAsFixed(0)),
                detailRow('Closing KM', b.closeKm.toStringAsFixed(0)),
                detailRow('Total KM', b.totalKm.toStringAsFixed(0)),
                if (b.driver.isNotEmpty) detailRow('Driver', b.driver),
                if (b.details.isNotEmpty) detailRow('Trip Details', b.details),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('CHARGES',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                if (b.billingType != 'Full Day') ...[
                  chargeRow('Trip / Service Charges', serviceCharges(b)),
                  chargeRow('Toll', b.toll),
                  chargeRow('Parking', b.parking),
                ],
                chargeRow(b.billingType == 'Full Day'
                  ? 'Total Amount'
                  : 'GRAND TOTAL', b.total, emphasize: true),
              ],
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.UrlLink(
                destination: googleReviewUrl,
                child: pw.Text('Leave a Google Review'),
              ),
            ),
            pw.SizedBox(height: 8),
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
Guest Phone: ${b.phone}
Vehicle: ${b.vehicleType}
Vehicle Number: ${b.vehicle}
Starting Date: ${date(b.startDate)}
Closing Date: ${date(b.closeDate)}
Total Days: ${b.days}
Starting KM: ${b.startKm.toStringAsFixed(0)}
Closing KM: ${b.closeKm.toStringAsFixed(0)}
Total KM: ${b.totalKm.toStringAsFixed(0)}
${b.billingType == 'Full Day' ? 'Extra Hours: ${extraHoursFor(b).toStringAsFixed(2)} Hours\n' : 'Trip / Service Charges: Rs ${serviceCharges(b).toStringAsFixed(2)}\n'}${b.billingType == 'Full Day' ? '' : 'Toll: Rs ${b.toll.toStringAsFixed(2)}\nParking: Rs ${b.parking.toStringAsFixed(2)}\n'}Total Amount: Rs ${b.total.toStringAsFixed(2)}

Thank you for choosing SVT Tours & Transport!

Google Review: $googleReviewUrl''';

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

  Future<void> pickContact() async {
    final selected = await pickNativeContact(context);
    if (!mounted || selected == null) return;
    setState(() {
      guest.text = selected['name'] as String? ?? '';
      phone.text = selected['phone'] as String? ?? '';
    });
  }

  void clear() {
    for (final c in [
      guest,
      phone,
      vehicle,
      driver,
      details,
      startKm,
      closeKm,
      totalKmController,
    ]) {
      c.clear();
    }
    toll.text = '0';
    parking.text = '0';
    setState(() {
      startDate = DateTime.now();
      closeDate = DateTime.now();
      startTime = const TimeOfDay(hour: 9, minute: 0);
      closeTime = const TimeOfDay(hour: 17, minute: 0);
      billing = 'KM Based';
      vehicleType = 'Sedan';
      totalKmController.clear();
      extraHourCharge.clear();
      totalAmount.clear();
    });
  }

  void updateKmFromCloseOrTotal() {
    if (updatingKm) return;
    final calculatedStart = n(closeKm) - n(totalKmController);
    updatingKm = true;
    startKm.text = calculatedStart >= 0 ? '$calculatedStart' : '';
    updatingKm = false;
    setState(() {});
  }

  void updateTotalFromStart() {
    if (updatingKm) return;
    final calculatedTotal = n(closeKm) - n(startKm);
    updatingKm = true;
    totalKmController.text = calculatedTotal >= 0 ? '$calculatedTotal' : '';
    updatingKm = false;
    setState(() {});
  }

  String? validateKm(String? value, TextEditingController controller) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Enter a non-negative number';
    if (controller == startKm && parsed > n(closeKm)) {
      return 'Starting KM cannot exceed Closing KM';
    }
    return null;
  }

  Widget fieldWithKmValidation(String label, TextEditingController controller,
      {required VoidCallback onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
        validator: (value) => validateKm(value, controller),
        decoration: InputDecoration(labelText: label),
      ),
    );
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field('Guest Phone', phone,
                      required: true, type: TextInputType.phone),
                ),
                IconButton(
                  tooltip: 'Choose contact',
                  onPressed: pickContact,
                  icon: const Icon(Icons.contacts_outlined),
                ),
              ],
            ),
            field('Vehicle Number', vehicle, required: true),
            DropdownButtonFormField<String>(
              initialValue: billing,
              decoration: const InputDecoration(labelText: 'Billing Type'),
              items: const [
                DropdownMenuItem(value: 'KM Based', child: Text('KM Based')),
                DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
              ],
              onChanged: (v) => setState(() => billing = v!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle Category'),
              items: const [
                DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                DropdownMenuItem(value: 'SUV', child: Text('SUV')),
              ],
              onChanged: (v) => setState(() => vehicleType = v!),
            ),
            const SizedBox(height: 10),
            fieldWithKmValidation('Starting KM', startKm,
                onChanged: updateTotalFromStart),
            fieldWithKmValidation('Closing KM', closeKm,
                onChanged: updateKmFromCloseOrTotal),
            fieldWithKmValidation('Total KM', totalKmController,
                onChanged: updateKmFromCloseOrTotal),
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
            if (billing == 'Full Day') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Starting Time: ${timeLabel(startTime)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () => chooseTime(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Closing Time: ${timeLabel(closeTime)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () => chooseTime(false),
              ),
              field('Extra Hour Charge', extraHourCharge,
                  type: TextInputType.number),
            ],
            const SizedBox(height: 10),
            field('Driver Name (Optional)', driver),
            field('Details of Trip (Optional)', details),
            field('Toll Amount (Optional)', toll, type: TextInputType.number),
            field('Parking Amount (Optional)', parking,
                type: TextInputType.number),
            Text('Calculated Amount: Rs ${calculatedTotal.toStringAsFixed(2)}'),
            field('Final Total Amount (editable)', totalAmount,
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
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(googleReviewUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Google Review'),
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
      totalKmController,
      toll,
      parking,
      extraHourCharge,
      totalAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}

class HistoryPage extends StatefulWidget {
  final List<Booking> bookings;
  final void Function(Booking) onEdit;
  final Future<void> Function(Booking) onDelete;
  const HistoryPage({
    super.key,
    required this.bookings,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? from, to;

  List<Booking> get filtered => widget.bookings.where((b) {
        if (from != null && b.startDate.isBefore(from!)) return false;
        if (to != null &&
            b.startDate
                .isAfter(DateTime(to!.year, to!.month, to!.day, 23, 59, 59))) {
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

  Future<void> confirmDelete(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('Delete the booking for ${booking.guest}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(booking);
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
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => widget.onEdit(b),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => confirmDelete(b),
                                icon: const Icon(Icons.delete_outline),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text('Rs ${b.total.toStringAsFixed(0)}'),
                              ),
                            ],
                          ),
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

  Future<void> pickContact() async {
    final selected = await pickNativeContact(context);
    if (!mounted || selected == null) return;
    setState(() {
      guest.text = selected['name'] as String? ?? '';
      phone.text = selected['phone'] as String? ?? '';
    });
  }

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
    final number =
        (widget.officeWhatsApp.isNotEmpty ? widget.officeWhatsApp : b.phone)
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
          Text('Pre-Booking', style: Theme.of(context).textTheme.headlineSmall),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Guest Phone'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Choose contact',
                      onPressed: pickContact,
                      icon: const Icon(Icons.contacts_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: vehicle,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle / Requirement'),
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
