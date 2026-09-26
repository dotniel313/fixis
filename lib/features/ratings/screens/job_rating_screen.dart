import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/fixis_ui.dart';

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
          icon: Image.asset(
            'assets/rating_wrench_orange.png',
            width: 22,
            height: 22,
            color: saved ? AppTheme.primaryOrange : AppTheme.slate500,
            colorBlendMode: BlendMode.srcIn,
          ),
          label: Text(
            snapshot.connectionState != ConnectionState.done || snapshot.hasError
                ? 'Opiniones del servicio'
                : saved
                    ? 'Ver opinión que envié'
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
  late Future<Map<String, dynamic>?> _receivedRating;
  late Future<Map<String, dynamic>?> _recipient;
  int _score = 0;
  bool _sending = false;
  Map<String, dynamic>? _submitted;

  @override
  void initState() {
    super.initState();
    _existingRating = _loadRating();
    _receivedRating = _loadReceivedRating();
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

  Future<Map<String, dynamic>?> _loadReceivedRating() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para ver tus opiniones.');
    final row = await client
        .from('job_ratings')
        .select('score, comment, created_at')
        .eq('job_id', widget.jobId)
        .eq('reviewed_id', user.id)
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
      setState(() {
        _submitted = Map<String, dynamic>.from(row as Map);
        _receivedRating = _loadReceivedRating();
      });
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
      appBar: AppBar(
        title: const Text('Opiniones del servicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar opiniones',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _existingRating = _loadRating();
              _receivedRating = _loadReceivedRating();
            }),
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
                                : 'Tu opinión enviada a $label',
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
                  _OpinionCard(
                    title: 'Opinión que envié',
                    score: (saved['score'] as num?)?.toInt() ?? 0,
                    comment: saved['comment']?.toString(),
                    caption: 'Esta opinión quedó registrada para este servicio.',
                    noCommentLabel: 'No dejé un comentario.',
                  ),
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
                const SizedBox(height: 28),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _receivedRating,
                  builder: (context, receivedSnapshot) {
                    if (receivedSnapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (receivedSnapshot.hasError) {
                      return const Text(
                        'No pudimos consultar la opinión recibida. Vuelve a abrir este servicio.',
                      );
                    }
                    final received = receivedSnapshot.data;
                    if (received == null) {
                      return FixisSurface(
                        shadows: const [],
                        border: Border.all(color: AppTheme.slate200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Opinión que recibí',
                              style: TextStyle(
                                color: AppTheme.darkSlate,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Todavía no recibiste una opinión de ${widget.recipientLabel} sobre este servicio.',
                            ),
                          ],
                        ),
                      );
                    }
                    return _OpinionCard(
                      title: 'Opinión que recibí',
                      score: (received['score'] as num?)?.toInt() ?? 0,
                      comment: received['comment']?.toString(),
                      caption: 'Así te calificó ${widget.recipientLabel} en este servicio.',
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpinionCard extends StatelessWidget {
  final String title;
  final int score;
  final String? comment;
  final String caption;
  final String noCommentLabel;

  const _OpinionCard({
    required this.title,
    required this.score,
    required this.comment,
    required this.caption,
    this.noCommentLabel = 'No dejó un comentario.',
  });

  @override
  Widget build(BuildContext context) {
    final text = comment?.trim();
    return FixisSurface(
      shadows: const [],
      border: Border.all(color: AppTheme.slate200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.darkSlate,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Image.asset(
                  'assets/rating_wrench_orange.png',
                  width: 27,
                  height: 27,
                  color: index < score
                      ? AppTheme.primaryOrange
                      : AppTheme.slate200,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Text('$score/5'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text == null || text.isEmpty ? noCommentLabel : text,
            style: const TextStyle(color: AppTheme.slate700, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            caption,
            style: const TextStyle(color: AppTheme.slate500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
