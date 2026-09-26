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
    final rows = await client
        .from('job_ratings')
        .select('job_id, score, comment, created_at, reviewer_role')
        .eq('reviewed_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    final ratings = List<Map<String, dynamic>>.from(rows);
    if (ratings.isEmpty) return ratings;

    // Jobs is protected by its own RLS; use only titles the viewer may read.
    final jobs = await client
        .from('jobs')
        .select('id, title')
        .inFilter('id', ratings.map((r) => r['job_id'].toString()).toList());
    final titles = {
      for (final job in jobs)
        job['id'].toString(): job['title']?.toString() ?? 'Servicio FIXIS',
    };
    return ratings.map((rating) => {
      ...rating,
      'job_title': titles[rating['job_id'].toString()] ?? 'Servicio FIXIS',
    }).toList();
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
                              const SizedBox(height: 8),
                              Text(
                                date == null
                                    ? 'Opinión de $role'
                                    : 'Opinión de $role · ${date.day}/${date.month}/${date.year}',
                                style: const TextStyle(
                                  color: AppTheme.slate500,
                                  fontSize: 12,
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
