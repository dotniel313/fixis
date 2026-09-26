import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';

class JobRatingScreen extends StatefulWidget {
  final String jobId;
  final String recipientLabel;

  const JobRatingScreen({
    super.key,
    required this.jobId,
    required this.recipientLabel,
  });

  @override
  State<JobRatingScreen> createState() => _JobRatingScreenState();
}

class _JobRatingScreenState extends State<JobRatingScreen> {
  final _comment = TextEditingController();
  late Future<Map<String, dynamic>?> _existingRating;
  int _score = 0;
  bool _sending = false;
  Map<String, dynamic>? _submitted;

  @override
  void initState() {
    super.initState();
    _existingRating = _loadRating();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadRating() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para calificar.');
    final row = await client
        .from('job_ratings')
        .select('score, comment, created_at')
        .eq('job_id', widget.jobId)
        .eq('reviewer_id', user.id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> _submit() async {
    if (_score == 0 || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await Supabase.instance.client.rpc(
        'submit_job_rating',
        params: {
          'p_job_id': widget.jobId,
          'p_score': _score,
          'p_comment': _comment.text.trim().isEmpty
              ? null
              : _comment.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() => _submitted = Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = switch (error.message) {
        'RATING_ALREADY_SUBMITTED' => 'Ya calificaste este servicio.',
        'PAYMENT_NOT_CONFIRMED' => 'El pago aún no está confirmado.',
        'JOB_NOT_ELIGIBLE_FOR_RATING' => 'El servicio todavía no se puede calificar.',
        'RATING_NOT_ALLOWED' => 'No puedes calificar este servicio.',
        _ => 'No pudimos guardar la calificación. Intenta nuevamente.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (error.message == 'RATING_ALREADY_SUBMITTED') {
        setState(() => _existingRating = _loadRating());
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos guardar la calificación.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Calificar servicio')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _existingRating,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('No pudimos consultar tu calificación. Actualiza la app e intenta nuevamente.'),
              );
            }
            final saved = _submitted ?? snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  saved == null
                      ? '¿Cómo fue tu experiencia con ${widget.recipientLabel}?'
                      : 'Tu calificación para ${widget.recipientLabel}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                if (saved != null) ...[
                  Text(
                    '${saved['score']} de 5 llaves',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (saved['comment'] != null) ...[
                    const SizedBox(height: 12),
                    Text(saved['comment'].toString()),
                  ],
                  const SizedBox(height: 12),
                  const Text('Gracias. Esta calificación quedó registrada para este servicio.'),
                ] else ...[
                  const Text('Califica de 1 a 5 llaves'),
                  const SizedBox(height: 8),
                  Wrap(
                    children: List.generate(5, (index) {
                      return IconButton(
                        tooltip: '${index + 1} de 5 llaves',
                        onPressed: _sending ? null : () => setState(() => _score = index + 1),
                        icon: Image.asset(
                          'assets/rating_wrench_orange.png',
                          width: 36,
                          height: 36,
                          color: index < _score ? AppTheme.primaryOrange : Colors.grey.shade400,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      );
                    }),
                  ),
                  if (_score > 0) Text('$_score de 5 llaves seleccionadas'),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _comment,
                    maxLength: 500,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _score == 0 || _sending ? null : _submit,
                    child: Text(_sending ? 'Enviando...' : 'Enviar calificación'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Solo puedes calificar una vez este servicio confirmado.'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
