import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../data/models.dart';
import '../../../state/auth.dart';
import '../../widgets/common.dart';

/// Edits the fields the web portal allows (PUT /students/updatePersonalDetails).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final Student _s;
  late final Map<String, TextEditingController> _c;
  String? _category;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _s = ref.read(studentProvider)!;
    _c = {
      'blood_group': TextEditingController(text: _s.bloodGroup),
      'percentage_10th': TextEditingController(text: _num(_s.cgpa10th)),
      'percentage_12th': TextEditingController(text: _num(_s.cgpa12th)),
      'dob': TextEditingController(text: _s.dob),
      'grad_cgpa': TextEditingController(text: _num(_s.graduationGpa)),
      'personal_mail': TextEditingController(text: _s.personalEmail),
      'contact': TextEditingController(text: _s.contactNumber),
      'alt_contact': TextEditingController(text: _s.altContactNumber),
      'present_address': TextEditingController(text: _s.presentAddress),
      'perm_address': TextEditingController(text: _s.permAddress),
      'aadhar': TextEditingController(text: _s.aadhar),
      'pan': TextEditingController(text: _s.pan),
    };
    for (final c in _c.values) {
      c.addListener(_markDirty);
    }
    _category = Catalog.categories.contains(_s.category) ? _s.category : null;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  static String _num(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    return s == '-1' ? '' : s;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// DOB is stored as "d/m/yyyy" by the web date picker.
  DateTime? _parseDob(String s) {
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return DateTime.tryParse(s);
    final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]), c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) return null;
    if (parts[0].length == 4) return DateTime(a, b, c);
    return DateTime(c, b, a);
  }

  Future<void> _pickDob() async {
    final initial = _parseDob(_c['dob']!.text) ?? DateTime(2003, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      helpText: 'Date of birth',
    );
    if (picked != null) _c['dob']!.text = '${picked.day}/${picked.month}/${picked.year}';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        for (final e in _c.entries) e.key: e.value.text.trim(),
        'category': _category,
        'roll': _s.rollNumber,
        'id': _s.id,
      };
      // Numeric fields: never send an empty string (keeps the stored value).
      const originals = {'percentage_10th': 'cgpa_10th', 'percentage_12th': 'cgpa_12th', 'grad_cgpa': 'graduation_gpa'};
      for (final e in originals.entries) {
        if ((body[e.key] as String?)?.isEmpty ?? true) body[e.key] = _s.raw[e.value];
      }
      if (!_s.isMasters) body['grad_cgpa'] = _s.graduationGpa;
      await ref.read(repositoryProvider).updatePersonalDetails(body);
      await ref.read(authProvider.notifier).refreshProfile();
      showToast('Changes applied successfully', type: ToastType.success);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _percent(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || d < 0 || d > 100) return 'Enter 0–100';
    return null;
  }

  String? _phone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return RegExp(r'^\+?\d{10,13}$').hasMatch(t) ? null : 'Enter a valid phone number';
  }

  Widget _field(
    String key,
    String label,
    IconData icon, {
    TextInputType? type,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _c[key],
        keyboardType: type,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: caps,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Text(
          title.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.palette.muted,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
        child: Column(children: children),
      ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(
          context,
          title: 'Discard changes?',
          message: 'Your edits haven\'t been saved.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit details')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              _group('Locked (from university records)', [
                _locked('Name', _s.name, Icons.person_rounded),
                _locked('Roll number', _s.rollNumber, Icons.badge_rounded),
                _locked('Degree · Branch · Batch', '${_s.degree} · ${_s.branch} · ${_s.batch}', Icons.school_rounded),
                _locked('College email', _s.email, Icons.mail_lock_rounded),
              ]),
              _group('Personal', [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: _c['dob'],
                    readOnly: true,
                    onTap: _pickDob,
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.cake_rounded),
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                ),
                _field('blood_group', 'Blood group', Icons.bloodtype_rounded, caps: TextCapitalization.characters),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    borderRadius: BorderRadius.circular(16),
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.groups_rounded)),
                    items: Catalog.categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() {
                      _category = v;
                      _dirty = true;
                    }),
                  ),
                ),
                _field('aadhar', 'Aadhaar number', Icons.fingerprint_rounded, type: TextInputType.number),
                _field('pan', 'PAN', Icons.credit_card_rounded, caps: TextCapitalization.characters),
              ]),
              _group('Academic', [
                _field(
                  'percentage_10th',
                  'Class 10 %',
                  Icons.looks_one_rounded,
                  type: const TextInputType.numberWithOptions(decimal: true),
                  validator: _percent,
                ),
                _field(
                  'percentage_12th',
                  'Class 12 %',
                  Icons.looks_two_rounded,
                  type: const TextInputType.numberWithOptions(decimal: true),
                  validator: _percent,
                ),
                if (_s.isMasters)
                  _field(
                    'grad_cgpa',
                    'Graduation GPA',
                    Icons.workspace_premium_rounded,
                    type: const TextInputType.numberWithOptions(decimal: true),
                  ),
              ]),
              _group('Contact', [
                _field(
                  'personal_mail',
                  'Personal email',
                  Icons.alternate_email_rounded,
                  type: TextInputType.emailAddress,
                  validator: (v) => (v ?? '').trim().isEmpty || (v ?? '').contains('@') ? null : 'Enter a valid email',
                ),
                _field('contact', 'Contact number', Icons.phone_rounded, type: TextInputType.phone, validator: _phone),
                _field(
                  'alt_contact',
                  'Alternate contact',
                  Icons.phone_forwarded_rounded,
                  type: TextInputType.phone,
                  validator: _phone,
                ),
                _field('present_address', 'Current address', Icons.home_rounded, maxLines: 3),
                _field('perm_address', 'Permanent address', Icons.cottage_rounded, maxLines: 3),
              ]),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: context.palette.card,
            border: Border(top: BorderSide(color: context.palette.border)),
          ),
          child: GradientButton(
            label: 'Save changes',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _dirty ? _save : null,
          ),
        ),
      ),
    );
  }

  Widget _locked(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
      ),
    ),
  );
}
