import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

/// Live account messages in the notifications screen of both mobile apps.
class AccountInbox extends StatefulWidget {
  const AccountInbox({
    super.key,
    required this.client,
    required this.onOpenTicket,
  });
  final SupabaseClient client;
  final ValueChanged<String> onOpenTicket;
  @override
  State<AccountInbox> createState() => _AccountInboxState();
}

class _AccountInboxState extends State<AccountInbox> {
  late final _user = widget.client.auth.currentUser?.id;
  late final _messages = _user == null
      ? Stream<List<Map<String, dynamic>>>.value([])
      : widget.client
            .from('inbox_messages')
            .stream(primaryKey: ['id'])
            .eq('profile_id', _user)
            .order('created_at', ascending: false)
            .limit(50);

  Future<void> _open(Map<String, dynamic> row) async {
    try {
      if (row['read_at'] == null) {
        await widget.client
            .from('inbox_messages')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', row['id']);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark this message as read.')),
        );
      }
    }
    if (mounted && row['ticket_id'] is String) {
      widget.onOpenTicket(row['ticket_id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messages,
        builder: (context, snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inbox', style: Theme.of(context).textTheme.titleLarge),
            if (snapshot.hasError)
              const Text('Could not load messages.')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (snapshot.data!.isEmpty)
              const Text('No messages yet.')
            else
              for (final row in snapshot.data!)
                ListTile(
                  leading: Icon(
                    row['read_at'] == null
                        ? Icons.mark_email_unread_outlined
                        : Icons.drafts_outlined,
                  ),
                  title: Text(row['title'] as String),
                  subtitle: Text(row['body'] as String),
                  onTap: () => _open(row),
                ),
            const SizedBox(height: 16),
          ],
        ),
      );
}

/// Displays newly delivered messages while the signed-in app is in use.
class InboxListener extends StatefulWidget {
  const InboxListener({
    super.key,
    required this.client,
    required this.profileId,
    required this.onOpen,
    required this.child,
  });
  final SupabaseClient client;
  final String profileId;
  final VoidCallback onOpen;
  final Widget child;
  @override
  State<InboxListener> createState() => _InboxListenerState();
}

class _InboxListenerState extends State<InboxListener> {
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _channel = widget.client
        .channel('inbox-alerts-${widget.profileId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'inbox_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: widget.profileId,
          ),
          callback: (event) {
            if (!mounted ||
                event.newRecord['profile_id'] !=
                    widget.client.auth.currentUser?.id) {
              return;
            }
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(event.newRecord['title'] as String),
                action: SnackBarAction(
                  label: 'Open inbox',
                  onPressed: widget.onOpen,
                ),
              ),
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    widget.client.removeChannel(_channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
