import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';

class ReceivedRatingsScreen extends StatefulWidget {
  const ReceivedRatingsScreen({super.key});

  @override
  State<ReceivedRatingsScreen> createState() => _ReceivedRatingsScreenState();
}

class _ReceivedRatingsScreenState extends State<ReceivedRatingsScreen> {
  late Future<List<Map<String, dynamic>>> _ratings;

  @override
  void initState() {
    super.initState();
    _ratings = _loadRatings();
  }

  Future<List<Map<String, dynamic>>> _loadRatings() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para ver tus reseñas.');
    final rows = await client.rpc('get_my_received_reviews');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _refresh() async {
    setState(() => _ratings = _loadRatings());
    await _ratings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Reseñas recibidas')),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ratings,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('No pudimos cargar tus reseñas. Reintentar'),
                ),
              );
            }
            final ratings = snapshot.data ?? const <Map<String, dynamic>>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  FixisSurface(
                    color: AppTheme.midnight,
                    shadows: const [],
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/rating_wrench_orange.png',
                          width: 42,
                          height: 42,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lo que opinan de ti',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mostrando ${ratings.length} ${ratings.length == 1 ? 'reseña' : 'reseñas'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const FixisSectionHeader(
                    title: 'Tus reseñas',
                    subtitle: 'Opiniones que recibiste por tus servicios',
                  ),
                  const SizedBox(height: 12),
                  if (ratings.isEmpty)
                    const FixisSurface(
                      shadows: [],
                      child: Text(
                        'Todavía no recibiste opiniones. Aparecerán aquí cuando un cliente o FIXI califique un servicio confirmado.',
                      ),
                    )
                  else
                    ...ratings.map((rating) {
                      final role = rating['reviewer_role'] == 'customer'
                          ? 'Cliente'
                          : 'FIXI';
                      final comment = rating['comment']?.toString().trim();
                      final reviewerName = rating['reviewer_name']?.toString().trim();
                      final displayName = reviewerName == null || reviewerName.isEmpty
                          ? (role == 'Cliente' ? 'Cliente FIXIS' : 'Profesional FIXIS')
                          : reviewerName;
                      final avatar = rating['reviewer_avatar_url']?.toString();
                      final avatarUri = avatar == null ? null : Uri.tryParse(avatar);
                      final showAvatar = avatarUri?.scheme == 'https' &&
                          avatarUri?.host.isNotEmpty == true;
                      final date = DateTime.tryParse(
                        rating['created_at']?.toString() ?? '',
                      )?.toLocal();
                      final score = (rating['score'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FixisSurface(
                          shadows: const [],
                          border: Border.all(color: AppTheme.slate200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.primaryOrange,
                                    child: ClipOval(
                                      child: showAvatar
                                          ? Image.network(
                                              avatar!,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.person, color: Colors.white),
                                            )
                                          : const Icon(Icons.person, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            color: AppTheme.darkSlate,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          date == null
                                              ? role
                                              : '$role · ${date.day}/${date.month}/${date.year}',
                                          style: const TextStyle(
                                            color: AppTheme.slate500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                rating['job_title']?.toString() ?? 'Servicio FIXIS',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkSlate,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ...List.generate(5, (index) => Image.asset(
                                        'assets/rating_wrench_orange.png',
                                        width: 23,
                                        height: 23,
                                        color: index < score
                                            ? AppTheme.primaryOrange
                                            : AppTheme.slate200,
                                        colorBlendMode: BlendMode.srcIn,
                                      )),
                                  const SizedBox(width: 10),
                                  Text('$score/5'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                comment == null || comment.isEmpty
                                    ? 'No dejó un comentario.'
                                    : comment,
                                style: const TextStyle(
                                  color: AppTheme.slate700,
                                  height: 1.4,
                                ),
                              ),

                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
