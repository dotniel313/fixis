import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';
import '../../auth/providers/auth_repository.dart';
import '../../auth/screens/login_screen.dart';
import '../../ratings/providers/ratings_repository.dart';
import '../../ratings/screens/received_ratings_screen.dart';
import '../providers/customer_repository.dart';

final customerLoyaltyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final result = await Supabase.instance.client.rpc('get_customer_loyalty_summary');
  if (result is List && result.isNotEmpty) {
    return Map<String, dynamic>.from(result.first as Map);
  }
  if (result is Map) return Map<String, dynamic>.from(result);
  return {'paid_services': 0, 'categories_used': 0};
});

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends ConsumerState<CustomerProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final jobsAsync = ref.watch(myCustomerJobsProvider);
    final loyaltyAsync = ref.watch(customerLoyaltyProvider);
    final ratingsAsync = ref.watch(receivedRatingsProvider);
    final user = ref.read(authRepositoryProvider).currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: FixisStatusPill(
                label: 'CLIENTE',
                color: AppTheme.primaryOrange,
                icon: Icons.home_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No fue posible cargar tu perfil.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (profile) {
            final name = profile?['full_name']?.toString().trim().isNotEmpty == true
                ? profile!['full_name'].toString().trim()
                : 'Cliente FIXIS';
            final phone = profile?['phone']?.toString().trim() ?? '';
            final city = profile?['city']?.toString().trim() ?? '';
            final accountStatus =
                profile?['account_status']?.toString() ?? 'active';
            final createdAt =
                DateTime.tryParse(profile?['created_at']?.toString() ?? '');
            final avatarUrl = profile?['avatar_url']?.toString();
            final ratingsCount =
                (ratingsAsync.value?['ratings_received'] as num?)?.toInt() ?? 0;
            final rating = double.tryParse(
              ratingsAsync.value?['average_score']?.toString() ?? '',
            );
  
            final jobs = jobsAsync.value ?? const <Map<String, dynamic>>[];
            final completed = jobs.where((job) {
              final status = job['status']?.toString();
              return status == 'customer_approved' || status == 'completed';
            }).length;
            final active = jobs.where((job) {
              final status = job['status']?.toString();
              return status != 'customer_approved' &&
                  status != 'completed' &&
                  status != 'cancelled';
            }).length;
  
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                _IdentityHero(
                  name: name,
                  email: user?.email ?? 'Correo no disponible',
                  avatarUrl: avatarUrl,
                  isUploading: _isUploadingAvatar,
                  onAvatarTap: user == null
                      ? null
                      : () => _showAvatarSourceSheet(user.id),
                  activeJobs: active,
                  completedJobs: completed,
                  ratingsCount: ratingsCount,
                  rating: rating,
                ),
                const SizedBox(height: 24),
                FixisSectionHeader(
                  title: 'Datos personales',
                  subtitle: 'Información de tu cuenta FIXIS',
                  trailing: IconButton(
                    tooltip: 'Editar',
                    onPressed: user == null
                        ? null
                        : () => _showEditProfileDialog(
                              context,
                              ref,
                              user.id,
                              name,
                              phone,
                              city,
                            ),
                    icon: const Icon(Icons.edit_rounded),
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Nombre',
                        value: name,
                        color: AppTheme.primaryBlue,
                      ),
                      const Divider(indent: 60),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        title: 'Teléfono',
                        value: phone.isEmpty ? 'No registrado' : phone,
                        color: AppTheme.primaryOrange,
                      ),
                      const Divider(indent: 60),
                      _InfoTile(
                        icon: Icons.location_city_outlined,
                        title: 'Ciudad',
                        value: city.isEmpty ? 'No registrada' : city,
                        color: AppTheme.primaryBlue,
                      ),
                      const Divider(indent: 60),
                      _InfoTile(
                        icon: Icons.email_outlined,
                        title: 'Correo',
                        value: user?.email ?? 'No disponible',
                        color: AppTheme.primaryOrange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Tu actividad',
                  subtitle: 'Resumen real de tus servicios FIXIS',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.handyman_rounded,
                        value: '$active',
                        label: 'Activos',
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.verified_rounded,
                        value: '$completed',
                        label: 'Completados',
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Cuenta',
                  subtitle: 'Estado y antigüedad de tu registro',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  shadows: const [],
                  color: AppTheme.blueSoft,
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cuenta FIXIS',
                              style: TextStyle(
                                color: AppTheme.darkSlate,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              createdAt == null
                                  ? 'Estado: $accountStatus'
                                  : 'Desde ${_formatDate(createdAt)} · $accountStatus',
                              style: const TextStyle(
                                color: AppTheme.slate500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FixisStatusPill(
                        label: accountStatus.toUpperCase(),
                        color: accountStatus == 'active'
                            ? AppTheme.success
                            : AppTheme.warning,
                        icon: Icons.verified_user_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Fidelización FIXIS',
                  subtitle: 'Actividad confirmada de tu cuenta',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: loyaltyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text(
                      'No pudimos cargar tu progreso. Desliza para actualizar.',
                    ),
                    data: (data) {
                      final paid = (data['paid_services'] as num?)?.toInt() ?? 0;
                      final categories =
                          (data['categories_used'] as num?)?.toInt() ?? 0;
                      final level = paid >= 10
                          ? 'Cliente habitual'
                          : paid >= 3
                              ? 'Cliente recurrente'
                              : 'Primeros servicios';
                      final nextGoal = paid >= 10 ? null : (paid >= 3 ? 10 : 3);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$paid ${paid == 1 ? 'servicio pagado' : 'servicios pagados'} · '
                            '$categories ${categories == 1 ? 'categoría' : 'categorías'}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppTheme.darkSlate,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Reconocimiento: $level'),
                          if (nextGoal != null) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: paid / nextGoal),
                            const SizedBox(height: 4),
                            Text('Te faltan ${nextGoal - paid} servicios pagados para el próximo reconocimiento.'),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            'El progreso cuenta solo pagos confirmados. '
                            'Estos reconocimientos no representan dinero, descuentos ni canjes.',
                            style: TextStyle(color: AppTheme.slate700, height: 1.45),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Legal y soporte',
                  subtitle: 'Ayuda e información de FIXIS',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.description_outlined,
                        title: 'Términos y condiciones',
                        onTap: () => _launch(
                          context,
                          'https://fixis.geotactics.com.ec/terminos.html',
                        ),
                      ),
                      const Divider(indent: 60),
                      _ActionTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Política de privacidad',
                        onTap: () => _launch(
                          context,
                          'https://fixis.geotactics.com.ec/privacidad.html',
                        ),
                      ),
                      const Divider(indent: 60),
                      _ActionTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Centro de ayuda',
                        onTap: () => _launch(
                          context,
                          'https://fixis.geotactics.com.ec/centro.html',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Sesión',
                  subtitle: 'Acceso a tu cuenta',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: ListTile(
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.warning,
                      ),
                    ),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.slate500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Eliminar cuenta',
                  subtitle: 'Control permanente de tus datos y acceso',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.20),
                  ),
                  child: ListTile(
                    onTap: () => _showDeleteAccountDialog(context, ref),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppTheme.danger,
                      ),
                    ),
                    title: const Text(
                      'Eliminar mi cuenta',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'Elimina permanentemente tu cuenta FIXIS y los datos asociados que no debamos conservar legalmente.',
                        style: TextStyle(
                          color: AppTheme.slate500,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAvatarSourceSheet(String userId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text('Elige cómo quieres actualizar tu foto.'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primaryOrange,
                ),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar(userId, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar(userId, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(
    String userId,
    ImageSource source,
  ) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 900,
      );
      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final file = File(image.path);
      final extension = image.path.split('.').last.toLowerCase();
      final fileName =
          '${userId}_customer_avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage.from('avatars_pro').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars_pro')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', userId);

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No fue posible actualizar la foto: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  static Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String currentName,
    String currentPhone,
    String currentCity,
  ) async {
    final name = TextEditingController(text: currentName);
    final phone = TextEditingController(text: currentPhone);
    final city = TextEditingController(text: currentCity);
    var saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text(
            'Editar perfil',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final cleanName = name.text.trim();
                      if (cleanName.isEmpty) return;

                      setDialogState(() => saving = true);
                      try {
                        await Supabase.instance.client
                            .from('profiles')
                            .update({
                          'full_name': cleanName,
                          'phone': phone.text.trim().isEmpty
                              ? null
                              : phone.text.trim(),
                          'city': city.text.trim().isEmpty
                              ? null
                              : city.text.trim(),
                        }).eq('id', userId);

                        ref.invalidate(userProfileProvider);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perfil actualizado'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No fue posible actualizar el perfil: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var deleting = false;

    await showDialog(
      context: context,
      barrierDismissible: !deleting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.danger,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    color: AppTheme.darkSlate,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Esta acción es permanente.\n\n'
            'Se eliminará tu cuenta FIXIS y la información personal asociada, '
            'excepto aquella que FIXIS deba conservar por obligaciones legales, '
            'contables, antifraude o de resolución de disputas.\n\n'
            'Tu historial puede perderse y no podrás recuperar esta cuenta.',
            style: TextStyle(
              color: AppTheme.slate700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: deleting
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      try {
                        await Supabase.instance.client
                            .rpc('delete_user_account');

                        await ref
                            .read(authRepositoryProvider)
                            .signOut();

                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (_) => false,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => deleting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No fue posible eliminar la cuenta: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(
                deleting ? 'Eliminando...' : 'Eliminar definitivamente',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _launch(
    BuildContext context,
    String urlString,
  ) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  static String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }
}

class _IdentityHero extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback? onAvatarTap;
  final int activeJobs;
  final int completedJobs;
  final int ratingsCount;
  final double? rating;

  const _IdentityHero({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isUploading,
    required this.onAvatarTap,
    required this.activeJobs,
    required this.completedJobs,
    required this.ratingsCount,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.midnight, AppTheme.midnightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(AppTheme.radiusLg),
        ),
        boxShadow: AppTheme.floatingShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: isUploading ? null : onAvatarTap,
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange,
                          width: 2.5,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.08),
                        backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: avatarUrl == null || avatarUrl!.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 34,
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: isUploading ? null : onAvatarTap,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.midnightSoft,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isUploading
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FixisStatusPill(
                      label: 'CLIENTE FIXIS',
                      color: AppTheme.primaryOrange,
                      icon: Icons.home_rounded,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.bolt_rounded,
                  value: '$activeJobs',
                  label: 'Activos',
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.verified_rounded,
                  value: '$completedJobs',
                  label: 'Completados',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.warning, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ratingsCount == 0 || rating == null
                        ? 'Aún sin calificaciones'
                        : '${rating!.toStringAsFixed(2)} / 5 · '
                          '$ratingsCount ${ratingsCount == 1 ? 'opinión' : 'opiniones'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FixisSurface(
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 13),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.darkSlate,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.darkSlate,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.blueSoft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.darkSlate,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.slate500,
      ),
    );
  }
}
