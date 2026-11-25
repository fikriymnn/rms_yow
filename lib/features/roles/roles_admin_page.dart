import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'role_editor_page.dart';
import 'role_models.dart';
import 'role_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

/// Master data role (hanya owner). Daftar role + jumlah pengguna dan izinnya.
class RolesAdminPage extends ConsumerWidget {
  const RolesAdminPage({super.key});

  void _open(BuildContext context, RoleInfo? role) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => RoleEditorPage(role: role)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    return Scaffold(
      appBar: RmsAppBar(title: const Text('Master role')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Role baru'),
      ),
      body: roles.when(
        loading: () => const SkeletonList(),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rolesProvider);
            await ref.read(rolesProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _RoleCard(role: list[i], onTap: () => _open(context, list[i])),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});
  final RoleInfo role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  role.locked ? Icons.lock_outline : Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${role.key} • ${role.userCount} pengguna',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          role.isSystem ? 'Bawaan' : 'Kustom',
                          tone: role.isSystem ? Tone.neutral : Tone.info,
                        ),
                        StatusPill(
                          role.locked
                              ? 'Akses penuh'
                              : '${role.permissions.length} izin',
                          tone: role.locked ? Tone.success : Tone.neutral,
                        ),
                        if (role.isStaff) const StatusPill('Dikelola manager'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
