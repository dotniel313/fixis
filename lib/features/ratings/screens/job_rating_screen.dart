import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';

class JobRatingActionButton extends StatefulWidget {
  final String jobId;
  final String recipientLabel;
  final String rateLabel;

  const JobRatingActionButton({
    super.key,
    required this.jobId,
    required this.recipientLabel,
    required this.rateLabel,
  });

  @override
  State<JobRatingActionButton> createState() => _JobRatingActionButtonState();
}

class _JobRatingActionButtonState extends State<JobRatingActionButton> {
  late Future<bool> _hasRating;

  @override
  void initState() {
    super.initState();
    _hasRating = _loadHasRating();
  }

  @override
  void didUpdateWidget(covariant JobRatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId) {
      _hasRating = _loadHasRating();
    }
  }

  Future<bool> _loadHasRating() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;
    final row = await client
        .from('job_ratings')
        .select('id')
        .eq('job_id', widget.jobId)
        .eq('reviewer_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<void> _openRating() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobRatingScreen(
          jobId: widget.jobId,
          recipientLabel: widget.recipientLabel,
        ),
      ),
    );
    if (mounted) setState(() => _hasRating = _loadHasRating());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasRating,
      builder: (context, snapshot) {
        final saved = snapshot.data == true;
        return OutlinedButton.icon(
          onPressed: _openRating,
          icon: Icon(saved ? Icons.rate_review_rounded : Icons.star_outline_rounded),
          label: Text(
            snapshot.hasError
                ? 'Ver calificación del servicio'
                : saved
                    ? 'Ver mi calificación'
                    : widget.rateLabel,
          ),
        );
      },
    );
  }
}

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
  late Future<Map<String, dynamic>?> _recipient;
  int _score = 0;
  bool _sending = false;
  Map<String, dynamic>? _submitted;

  @override
  void initState() {
    super.initState();
    _existingRating = _loadRating();
    _recipient = _loadRecipient();
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

  Future<Map<String, dynamic>?> _loadRecipient() async {
    final result = await Supabase.instance.client.rpc(
      'get_rating_recipient',
      params: {'p_job_id': widget.jobId},
    );
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
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
                FutureBuilder<Map<String, dynamic>?>(
                  future: _recipient,
                  builder: (context, recipientSnapshot) {
                    final recipient = recipientSnapshot.data;
                    final name = recipient?['recipient_name']?.toString().trim();
                    final label = name == null || name.isEmpty
                        ? widget.recipientLabel
                        : name;
                    final avatar = recipient?['recipient_avatar_url']?.toString();
                    final avatarUri = avatar == null ? null : Uri.tryParse(avatar);
                    final showAvatar = avatarUri?.scheme == 'https' &&
                        avatarUri?.host.isNotEmpty == true;
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primaryOrange,
                          child: ClipOval(
                            child: showAvatar
                                ? Image.network(
                                    avatar!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person, color: Colors.white),
                                  )
                                : const Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            saved == null
                                ? '¿Cómo fue tu experiencia con $label?'
                                : 'Tu calificación para $label',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
