import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import '../auth/auth_scaffold.dart' show FormBanner;

Future<void> showCgpaUpdateSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => const _CgpaUpdateSheet(),
  );
}

/// Pulls the latest grades from IMS (same flow as the web "Update CGPA" modal).
class _CgpaUpdateSheet extends ConsumerStatefulWidget {
  const _CgpaUpdateSheet();

  @override
  ConsumerState<_CgpaUpdateSheet> createState() => _CgpaUpdateSheetState();
}

class _CgpaUpdateSheetState extends ConsumerState<_CgpaUpdateSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).updateCgpa(password: _password.text, captcha: _captcha.text.trim());
      await ref.read(authProvider.notifier).refreshProfile();
      showToast('CGPA updated successfully', type: ToastType.success);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      ref.invalidate(captchaProvider);
      _captcha.clear();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: IconBadge(Icons.sync_lock_rounded, size: 56, gradient: AppColors.brandGradient)),
              const SizedBox(height: 14),
              Text('Update CGPA', textAlign: TextAlign.center, style: context.text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Verify your identity with your IMS password to import your latest grades.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'IMS password',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Enter your IMS password' : null,
              ),
              const SizedBox(height: 14),
              CaptchaField(controller: _captcha),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: FormBanner(message: _error!),
                      ),
              ),
              GradientButton(
                label: 'Continue',
                icon: Icons.verified_user_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
