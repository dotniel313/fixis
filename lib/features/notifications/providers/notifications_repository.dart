import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(Supabase.instance.client);
});

final myNotificationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }

  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .where((row) => row['user_id']?.toString() == user.id)
            .take(100)
            .toList(growable: false),
      );
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(myNotificationsStreamProvider).valueOrNull;
  if (notifications == null) return 0;

  return notifications.where((item) => item['read_at'] == null).length;
});

class NotificationsRepository {
  final SupabaseClient _supabase;

  NotificationsRepository(this._supabase);

  Future<void> markAsRead(String notificationId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', user.id);
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', user.id)
        .isFilter('read_at', null);
  }
}
