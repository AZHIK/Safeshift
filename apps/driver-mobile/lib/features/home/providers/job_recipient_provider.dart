import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client.dart';

/// The person receiving the goods, when the customer named someone else.
typedef JobRecipient = ({String name, String phone});

/// Recipient for a job, or null when the customer receives it themselves.
final jobRecipientProvider = FutureProvider.autoDispose
    .family<JobRecipient?, String>((ref, jobId) async {
      final row = await ref
          .read(supabaseProvider)
          .rpc<Map<String, dynamic>>(
            'job_recipient',
            params: <String, dynamic>{'p_job_id': jobId},
          );
      final phone = row['phone'] as String?;
      if (phone == null || phone.isEmpty) return null;
      return (name: (row['name'] as String?) ?? 'Recipient', phone: phone);
    });
