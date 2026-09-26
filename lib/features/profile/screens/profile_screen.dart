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
import '../../gamification/screens/gamification_screen.dart';
import '../../ratings/providers/ratings_repository.dart';
import '../../ratings/screens/received_ratings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Usuario no logueado');

      final imageFile = File(image.path);
      final fileExtension = image.path.split('.').last;
      final fileName =
          '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await Supabase.instance.client.storage.from('avatars_pro').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('avatars_pro')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', user.id);

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
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
                label: 'PRO',
                color: AppTheme.primaryOrange,
                icon: Icons.verified_rounded,
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
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No fue posible cargar tu perfil.\n$err',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (profile) {
            final name = profile?['full_name']?.toString() ?? 'Profesional FIXIS';
            final category = profile?['category']?.toString() ?? 'Especialista';
            final phone = profile?['phone']?.toString() ?? 'Sin número';
            final ratingsCount =
                (ratingsAsync.value?['ratings_received'] as num?)?.toInt() ?? 0;
            final rating = ratingsCount == 0
                ? '—'
                : ((ratingsAsync.value?['average_score'] as num?)?.toDouble() ?? 0)
                    .toStringAsFixed(2);
            final jobs = profile?['total_jobs']?.toString() ?? '0';
            final avatarUrl = profile?['avatar_url']?.toString();
            final city =
                profile?['city']?.toString() ?? 'Ciudad no especificada';
            final experience =
                profile?['experience']?.toString() ?? 'Sin especificar';
            final bank =
                profile?['bank']?.toString() ?? 'Pendiente de registro';
            final accountType = profile?['account_type']?.toString() ?? '';
            final accountNumber = profile?['account_number']?.toString() ?? '';
            final bio = profile?['bio']?.toString() ??
                'Soy un profesional verificado en FIXIS, listo para brindar un servicio responsable y de calidad.';
  
            var maskedAccount = '**** ****';
            if (accountNumber.length >= 4) {
              maskedAccount =
                  '•••• ${accountNumber.substring(accountNumber.length - 4)}';
            }
  
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                _buildIdentityHero(
                  name: name,
                  category: category,
                  rating: rating,
                  jobs: jobs,
                  avatarUrl: avatarUrl,
                ),
                if (ratingsCount > 0) ...[
                  const SizedBox(height: 8),
                  Text('$ratingsCount calificaciones recibidas'),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReceivedRatingsScreen(),
                    ),
                  ),
                  icon: Image.asset(
                    'assets/rating_wrench_orange.png',
                    width: 22,
                    height: 22,
                  ),
                  label: const Text('Leer reseñas recibidas'),
                ),
                const SizedBox(height: 18),
                _buildLevelShortcut(context),
                const SizedBox(height: 24),
                FixisSectionHeader(
                  title: 'Sobre mí',
                  subtitle: 'La presentación que tus clientes verán',
                  trailing: IconButton(
                    onPressed: user == null
                        ? null
                        : () => _showEditBioDialog(context, bio, user.id),
                    icon: const Icon(Icons.edit_note_rounded),
                    color: AppTheme.primaryBlue,
                    tooltip: 'Editar biografía',
                  ),
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.format_quote_rounded,
                        color: AppTheme.primaryOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bio,
                          style: const TextStyle(
                            color: AppTheme.slate700,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Información profesional',
                  subtitle: 'Datos visibles de tu perfil FIXIS',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        Icons.location_city_rounded,
                        'Ciudad de operación',
                        city,
                        AppTheme.primaryBlue,
                      ),
                      const Divider(indent: 60),
                      _buildInfoTile(
                        Icons.work_history_rounded,
                        'Experiencia',
                        experience.contains('año')
                            ? experience
                            : '$experience años',
                        AppTheme.primaryOrange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Cuenta de pago',
                  subtitle: 'Información privada para tus liquidaciones',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  shadows: const [],
                  color: AppTheme.successSoft,
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bank,
                              style: const TextStyle(
                                color: AppTheme.darkSlate,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$accountType · $maskedAccount',
                              style: const TextStyle(
                                color: AppTheme.slate500,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const FixisStatusPill(
                        label: 'PRIVADO',
                        color: AppTheme.success,
                        icon: Icons.lock_outline_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Seguridad y cuenta',
                  subtitle: 'Datos asociados a tu acceso',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        Icons.phone_outlined,
                        'Teléfono registrado',
                        phone,
                        AppTheme.primaryBlue,
                      ),
                      const Divider(indent: 60),
                      _buildInfoTile(
                        Icons.email_outlined,
                        'Correo electrónico',
                        user?.email ?? 'correo no disponible',
                        AppTheme.primaryOrange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Legal y soporte',
                  subtitle: 'Información y ayuda FIXIS',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(color: AppTheme.slate200),
                  child: Column(
                    children: [
                      _buildActionTile(
                        Icons.description_outlined,
                        'Términos y condiciones',
                        () => _launchURL(
                          'https://fixis.geotactics.com.ec/terminos.html',
                        ),
                      ),
                      const Divider(indent: 60),
                      _buildActionTile(
                        Icons.privacy_tip_outlined,
                        'Política de privacidad',
                        () => _launchURL(
                          'https://fixis.geotactics.com.ec/privacidad.html',
                        ),
                      ),
                      const Divider(indent: 60),
                      _buildActionTile(
                        Icons.help_outline_rounded,
                        'Centro de ayuda',
                        () => _launchURL(
                          'https://fixis.geotactics.com.ec/centro.html',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const FixisSectionHeader(
                  title: 'Cuenta',
                  subtitle: 'Sesión y administración de tu cuenta',
                ),
                const SizedBox(height: 10),
                FixisSurface(
                  padding: EdgeInsets.zero,
                  shadows: const [],
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.14),
                  ),
                  child: Column(
                    children: [
                      ListTile(
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
                        leading: _actionIcon(
                          Icons.logout_rounded,
                          AppTheme.warning,
                        ),
                        title: const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: AppTheme.darkSlate,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right_rounded),
                      ),
                      Divider(
                        indent: 60,
                        color: AppTheme.danger.withValues(alpha: 0.10),
                      ),
                      ListTile(
                        onTap: () => _showDeleteAccountDialog(context),
                        leading: _actionIcon(
                          Icons.delete_forever_rounded,
                          AppTheme.danger,
                        ),
                        title: const Text(
                          'Eliminar mi cuenta',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIdentityHero({
    required String name,
    required String category,
    required String rating,
    required String jobs,
    required String? avatarUrl,
  }) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryOrange,
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 39,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.10),
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap:
                          _isUploading ? null : _uploadProfilePicture,
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
                        child: _isUploading
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FixisStatusPill(
                      label: 'VERIFICADO',
                      color: AppTheme.success,
                      icon: Icons.verified_user_rounded,
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
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category,
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroMetric(
                    Icons.star_rounded,
                    AppTheme.warning,
                    rating,
                    'Calificación',
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                Expanded(
                  child: _heroMetric(
                    Icons.task_alt_rounded,
                    AppTheme.success,
                    jobs,
                    'Trabajos',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelShortcut(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GamificationScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.warning,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel FIXIS',
                      style: TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Revisa tu progreso y servicios confirmados',
                      style: TextStyle(
                        color: AppTheme.slate500,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroMetric(
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
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
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.slate500,
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _showEditBioDialog(
    BuildContext context,
    String currentBio,
    String userId,
  ) async {
    final bioController = TextEditingController(text: currentBio);
    var isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            title: const Text(
              'Biografía profesional',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.darkSlate,
              ),
            ),
            content: TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 150,
              decoration: const InputDecoration(
                hintText:
                    'Cuéntale a tus clientes sobre tu experiencia...',
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          await Supabase.instance.client
                              .from('profiles')
                              .update({
                            'bio': bioController.text.trim(),
                          }).eq('id', userId);

                          ref.invalidate(userProfileProvider);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Biografía actualizada'),
                              ),
                            );
                          }
                        } catch (_) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No fue posible guardar la biografía',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
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
          );
        },
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    var isDeleting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: AppTheme.danger,
                ),
                SizedBox(width: 10),
                Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkSlate,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Perderás tu historial, calificaciones y ganancias pendientes.\n\nEsta acción es irreversible.',
              style: TextStyle(
                color: AppTheme.slate700,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Mantener cuenta'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
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
                        } catch (_) {
                          setDialogState(() => isDeleting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error al procesar la solicitud.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Sí, eliminar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
