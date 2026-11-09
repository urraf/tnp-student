import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';

/// QR payload identical to the web portal's admit card.
String admitQrData(Student s) =>
    jsonEncode({'student_name': s.name, 'student_roll': s.rollNumber, 'student_email': s.email, 'studentID': s.id});

Map<String, String> _admitFields(Student s) => {
  'Name': s.name,
  'Branch': s.branch,
  'Degree': s.degree,
  'Batch': s.batch,
  'Roll Number': s.rollNumber,
  'Email': s.email,
  'Contact': s.contactNumber,
  'Personal Email': s.personalEmail,
  'Gender': s.gender,
  'Blood Group': s.bloodGroup,
  'Current Address': s.presentAddress,
};

Future<void> showAdmitCard(BuildContext context, Student s) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => _AdmitCardSheet(student: s),
  );
}

class _AdmitCardSheet extends StatefulWidget {
  const _AdmitCardSheet({required this.student});
  final Student student;

  @override
  State<_AdmitCardSheet> createState() => _AdmitCardSheetState();
}

class _AdmitCardSheetState extends State<_AdmitCardSheet> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await buildAdmitCardPdf(widget.student);
      await Printing.sharePdf(bytes: bytes, filename: 'admit_card_${widget.student.rollNumber}.pdf');
    } catch (e) {
      showToast('Could not create the hall card: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        children: [
          Text('Hall card', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text('Show this QR at placement drives', style: TextStyle(color: context.palette.muted)),
          const SizedBox(height: 20),
          Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: context.palette.border),
                  boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: admitQrData(s),
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.navyDeep),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: AppColors.navyDeep,
                      ),
                      embeddedImage: const AssetImage('assets/images/logo.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(36, 42)),
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.name,
                      style: const TextStyle(color: AppColors.navyDeep, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.rollNumber} · ${s.degree} ${s.branch}',
                      style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack, duration: 500.ms),
          const SizedBox(height: 22),
          GradientButton(
            label: 'Download hall card (PDF)',
            icon: Icons.download_rounded,
            loading: _busy,
            onPressed: _download,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: admitQrData(s)));
              showToast('QR data copied', type: ToastType.success);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy QR data'),
          ),
        ],
      ),
    );
  }
}

/// Recreates the web portal's jsPDF admit card with the `pdf` package.
Future<Uint8List> buildAdmitCardPdf(Student s) async {
  final logoBytes = (await rootBundle.load('assets/images/logo_full.png')).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final doc = pw.Document(title: 'Admit Card - ${s.name}', author: 'TnP NSUT');
  final fields = _admitFields(s).entries.toList();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Image(logo, width: 56, height: 56),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Training and Placement Cell', style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'AZAD HIND FAUJ MARG, SECTOR-3, DWARKA, NEW DELHI - 110078',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 68),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'ADMIT CARD',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: admitQrData(s), width: 140, height: 140),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final f in fields)
                      pw.SizedBox(
                        width: 160,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${f.key}:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text(f.value.isEmpty ? '-' : f.value, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Text(
              'This is an official admit card. Please bring it to the examination center.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
