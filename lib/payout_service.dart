import 'package:supabase_flutter/supabase_flutter.dart';

class PayoutService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The teacher's saved bKash number, or null if none yet.
  Future<String?> fetchBkashNumber() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('teacher_payout_accounts')
        .select('bkash_number')
        .eq('teacher_id', userId)
        .maybeSingle();
    return data?['bkash_number'] as String?;
  }

  Future<void> saveBkashNumber(String number) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('teacher_payout_accounts').upsert(
      {
        'teacher_id': userId,
        'bkash_number': number,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'teacher_id',
    );
  }
}