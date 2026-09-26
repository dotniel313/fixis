import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final receivedRatingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return {'ratings_received': 0, 'average_score': null};
  final response = await client.rpc('get_my_rating_summary');
  if (response is List && response.isNotEmpty) {
    return Map<String, dynamic>.from(response.first as Map);
  }
  if (response is Map) return Map<String, dynamic>.from(response);
  return {'ratings_received': 0, 'average_score': null};
});
