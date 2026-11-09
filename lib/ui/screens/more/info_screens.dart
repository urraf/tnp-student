import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            gradient: AppColors.heroGradient,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const IconBadge(Icons.apartment_rounded, size: 52, gradient: AppColors.brandGradient),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Training & Placement Cell', style: context.text.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        'New TnP Building, Near Guest House\nNetaji Subhas University of Technology (NSUT)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).entrance(0),
          const SizedBox(height: 16),
          const _Person(
            name: 'Rajesh Rawat',
            role: 'Assistant Coordinator',
            phones: ['+919205475078', '+919810472670'],
            email: 'rajesh.rawat@nsut.ac.in',
          ).entrance(1),
          const SizedBox(height: 12),
          const _Person(
            name: 'Dr. MPS Bhatia',
            role: 'Prof. In-Charge, Training and Placement',
            phones: ['+919818192294'],
          ).entrance(2),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.name, required this.role, required this.phones, this.email});
  final String name;
  final String role;
  final List<String> phones;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: name.replaceAll('Dr. ', ''), size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.titleMedium),
                    Text(role, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in phones)
                ActionChip(
                  avatar: const Icon(Icons.call_rounded, size: 18, color: AppColors.success),
                  label: Text(p),
                  onPressed: () => openLink(context, 'tel:$p'),
                ),
              if (email != null)
                ActionChip(
                  avatar: const Icon(Icons.mail_rounded, size: 18, color: AppColors.info),
                  label: Text(email!),
                  onPressed: () => openLink(context, 'mailto:$email'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
