import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/reference_number.dart';
import '../../../core/widgets/feedback/app_empty_state.dart';
import '../../../core/widgets/feedback/app_error_view.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';

String _date(dynamic value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('d MMM yyyy, HH:mm').format(parsed.toLocal());
}

String _statusLabel(dynamic value) {
  final text = (value ?? '').toString();
  if (text.isEmpty) return 'Unknown';
  return text
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _userId(WidgetRef ref) {
  final id = ref.read(supabaseProvider).auth.currentUser?.id;
  if (id == null) throw StateError('Sign in again to continue.');
  return id;
}

Future<Map<String, dynamic>> _myProfile(WidgetRef ref) async {
  final client = ref.read(supabaseProvider);
  final row = await client
      .from('profiles')
      .select('id, full_name, display_name, phone, email, default_country_id, preferred_language_id, preferred_currency_id')
      .eq('id', _userId(ref))
      .single();
  return Map<String, dynamic>.from(row);
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(AppSizes.md), child: child),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color = AppColors.primary});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      );
}

// ---------------------------------------------------------------------------
// Business accounts and recurring jobs
// ---------------------------------------------------------------------------
class BusinessHubScreen extends ConsumerWidget {
  const BusinessHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(supabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: client
            .from('business_members')
            .select('role, business_accounts(id, legal_name, trading_name, registration_number, tax_id, is_active, verified_at, current_balance, credit_limit)')
            .eq('profile_id', _userId(ref)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: () => (context as Element).markNeedsBuild());
          }
          final memberships = (snapshot.data ?? <Map<String, dynamic>>[])
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Business account', style: TextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      'Register your company to book recurring jobs, add team members, and receive invoices.',
                      style: TextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSizes.md),
                    FilledButton.icon(
                      onPressed: () => context.push('/business/register'),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Register a business'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (memberships.isEmpty)
                const AppEmptyState(
                  icon: Icons.business_outlined,
                  title: 'No business accounts yet',
                  message: 'Register a company to unlock recurring jobs and consolidated billing.',
                )
              else
                ...memberships.map((row) {
                  final account = Map<String, dynamic>.from(row['business_accounts'] as Map);
                  final verified = account['verified_at'] != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.md),
                    child: _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (account['trading_name'] ?? account['legal_name']).toString(),
                                  style: TextStyles.title.copyWith(fontSize: 16),
                                ),
                              ),
                              _Pill(
                                label: verified ? 'Verified' : 'Pending review',
                                color: verified ? AppColors.success : AppColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${account['legal_name']} · ${account['registration_number'] ?? 'No registration number'}',
                            style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            verified
                                ? 'Recurring jobs are enabled. Credit limit TZS ${NumberFormat('#,##0').format(account['credit_limit'] ?? 0)}.'
                                : 'An admin must verify the business before recurring jobs can be scheduled.',
                            style: TextStyles.body,
                          ),
                          const SizedBox(height: AppSizes.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/business/recurring'),
                                  icon: const Icon(Icons.repeat_rounded),
                                  label: const Text('Recurring jobs'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class BusinessRegisterScreen extends ConsumerStatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  ConsumerState<BusinessRegisterScreen> createState() => _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState extends ConsumerState<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legal = TextEditingController();
  final _trading = TextEditingController();
  final _registration = TextEditingController();
  final _tax = TextEditingController();
  final _industry = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_legal, _trading, _registration, _tax, _industry, _email, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final profile = await _myProfile(ref);
      final countryId = profile['default_country_id'] as String?;
      if (countryId == null) throw StateError('Your profile has no country. Contact support.');
      final city = await client.from('cities').select('id').eq('country_id', countryId).limit(1).maybeSingle();
      final account = await client
          .from('business_accounts')
          .insert({
            'country_id': countryId,
            'city_id': city?['id'],
            'legal_name': _legal.text.trim(),
            'trading_name': _trading.text.trim().isEmpty ? null : _trading.text.trim(),
            'registration_number': _registration.text.trim().isEmpty ? null : _registration.text.trim(),
            'tax_id': _tax.text.trim().isEmpty ? null : _tax.text.trim(),
            'industry': _industry.text.trim().isEmpty ? null : _industry.text.trim(),
            'contact_email': _email.text.trim().isEmpty ? null : _email.text.trim(),
            'contact_phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          })
          .select('id')
          .single();
      final accountId = account['id'] as String;
      await client.from('verification_requests').insert({
        'request_type': 'business_verification',
        'business_account_id': accountId,
        'requested_by': _userId(ref),
        'status': 'pending',
        'priority': 'normal',
      });
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Business submitted for verification.');
      context.go('/business');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register business')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            TextFormField(
              controller: _legal,
              decoration: const InputDecoration(labelText: 'Legal name *'),
              validator: (value) => (value ?? '').trim().length < 2 ? 'Enter the registered legal name' : null,
            ),
            const SizedBox(height: AppSizes.sm),
            TextFormField(controller: _trading, decoration: const InputDecoration(labelText: 'Trading name')),
            const SizedBox(height: AppSizes.sm),
            TextFormField(
              controller: _registration,
              decoration: const InputDecoration(labelText: 'BRELA registration number *'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Registration number is required' : null,
            ),
            const SizedBox(height: AppSizes.sm),
            TextFormField(controller: _tax, decoration: const InputDecoration(labelText: 'TIN')),
            const SizedBox(height: AppSizes.sm),
            TextFormField(controller: _industry, decoration: const InputDecoration(labelText: 'Industry')),
            const SizedBox(height: AppSizes.sm),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Contact email'),
            ),
            const SizedBox(height: AppSizes.sm),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact phone'),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Submit for verification'),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              'An admin reviews the registration number and TIN. Recurring jobs unlock after approval.',
              textAlign: TextAlign.center,
              style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class RecurringTemplatesScreen extends ConsumerWidget {
  const RecurringTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(supabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring jobs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New template'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: client
            .from('recurring_job_templates')
            .select('id, name, recurrence_rule, time_of_day, timezone, is_active, business_account_id, scheduled_jobs(id, scheduled_for, status)')
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return const AppEmptyState(
              icon: Icons.repeat_rounded,
              title: 'No recurring templates',
              message: 'Create a weekly or daily template. It will generate scheduled jobs for verified businesses.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, 100),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              final jobs = (row['scheduled_jobs'] as List?) ?? const [];
              return _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(row['name'].toString(), style: TextStyles.title.copyWith(fontSize: 15))),
                        _Pill(
                          label: row['is_active'] == true ? 'Active' : 'Paused',
                          color: row['is_active'] == true ? AppColors.success : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row['recurrence_rule']} · ${row['time_of_day']} ${row['timezone']}',
                      style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text('${jobs.length} generated occurrence(s)', style: TextStyles.body),
                    const SizedBox(height: AppSizes.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await client.from('recurring_job_templates').update({'is_active': !(row['is_active'] == true)}).eq('id', row['id']);
                          if (context.mounted) context.pushReplacement('/business/recurring');
                        },
                        icon: Icon(row['is_active'] == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(row['is_active'] == true ? 'Pause' : 'Resume'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseProvider);
    final memberships = await client.from('business_members').select('business_account_id, role, business_accounts(verified_at)').eq('profile_id', _userId(ref));
    final verified = memberships.where((row) {
      final account = row['business_accounts'] as Map?;
      final canManage = row['role'] == 'owner' || row['role'] == 'admin';
      return canManage && account?['verified_at'] != null;
    }).toList();
    if (!context.mounted) return;
    if (verified.isEmpty) {
      AppSnackbar.showInfo(context, 'Verify a business account before creating recurring jobs.');
      return;
    }
    final vehicleTypes = await client.from('vehicle_types').select('id, name').eq('is_active', true).order('display_order');
    if (!context.mounted) return;
    final savedAddresses = await client.from('saved_addresses').select('address_id, label, addresses(line_1)').eq('profile_id', _userId(ref));
    if (!context.mounted) return;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final rule = TextEditingController(text: 'FREQ=WEEKLY;BYDAY=MO');
    final time = TextEditingController(text: '08:00');
    String accountId = verified.first['business_account_id'].toString();
    String? vehicleTypeId = vehicleTypes.isNotEmpty ? vehicleTypes.first['id'].toString() : null;
    String? pickupId;
    String? destinationId;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, MediaQuery.viewInsetsOf(context).bottom + AppSizes.lg),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('New recurring template', style: TextStyles.headline),
                const SizedBox(height: AppSizes.md),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Business account'),
                  items: verified.map((row) => DropdownMenuItem(value: row['business_account_id'].toString(), child: Text(row['business_account_id'].toString()))).toList(),
                  onChanged: (value) => accountId = value ?? accountId,
                ),
                const SizedBox(height: AppSizes.sm),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Template name *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null),
                const SizedBox(height: AppSizes.sm),
                TextFormField(controller: rule, decoration: const InputDecoration(labelText: 'RRULE *', hintText: 'FREQ=WEEKLY;BYDAY=MO,WE')), 
                const SizedBox(height: AppSizes.sm),
                TextFormField(controller: time, decoration: const InputDecoration(labelText: 'Time (HH:mm) *', hintText: '08:00'), validator: (v) => RegExp(r'^\d{2}:\d{2}$').hasMatch((v ?? '').trim()) ? null : 'Use HH:mm'),
                const SizedBox(height: AppSizes.sm),
                DropdownButtonFormField<String>(
                  initialValue: vehicleTypeId,
                  decoration: const InputDecoration(labelText: 'Vehicle type *'),
                  items: vehicleTypes.map((row) => DropdownMenuItem(value: row['id'].toString(), child: Text(row['name'].toString()))).toList(),
                  onChanged: (value) => setModalState(() => vehicleTypeId = value),
                ),
                const SizedBox(height: AppSizes.sm),
                DropdownButtonFormField<String>(
                  initialValue: pickupId,
                  decoration: const InputDecoration(labelText: 'Pickup saved address'),
                  items: savedAddresses.map((row) => DropdownMenuItem(value: row['address_id'].toString(), child: Text((row['label'] ?? (row['addresses'] as Map?)?['line_1'] ?? 'Address').toString()))).toList(),
                  onChanged: (value) => setModalState(() => pickupId = value),
                ),
                const SizedBox(height: AppSizes.sm),
                DropdownButtonFormField<String>(
                  initialValue: destinationId,
                  decoration: const InputDecoration(labelText: 'Destination saved address'),
                  items: savedAddresses.map((row) => DropdownMenuItem(value: row['address_id'].toString(), child: Text((row['label'] ?? (row['addresses'] as Map?)?['line_1'] ?? 'Address').toString()))).toList(),
                  onChanged: (value) => setModalState(() => destinationId = value),
                ),
                const SizedBox(height: AppSizes.lg),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || vehicleTypeId == null) return;
                    try {
                      await client.from('recurring_job_templates').insert({
                        'business_account_id': accountId,
                        'created_by': _userId(ref),
                        'name': name.text.trim(),
                        'recurrence_rule': rule.text.trim(),
                        'time_of_day': time.text.trim(),
                        'timezone': 'Africa/Dar_es_Salaam',
                        'vehicle_type_id': vehicleTypeId,
                        'pickup_address_id': pickupId,
                        'destination_address_id': destinationId,
                        'is_active': true,
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      if (context.mounted) AppSnackbar.showError(context, error.toString());
                    }
                  },
                  child: const Text('Create template'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) context.pushReplacement('/business/recurring');
  }
}

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends ConsumerState<NotificationPreferencesScreen> {
  static const _categories = <String>['job_updates', 'payment', 'promotions', 'safety_alerts', 'chat', 'system'];
  static const _channels = <String>['push', 'sms', 'email'];
  final Map<String, bool> _values = {};
  final _quietStart = TextEditingController();
  final _quietEnd = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(supabaseProvider).from('notification_preferences').select().eq('profile_id', _userId(ref));
      for (final category in _categories) {
        for (final channel in _channels) {
          _values['$category|$channel'] = true;
        }
      }
      for (final row in rows) {
        _values['${row['category']}|${row['channel']}'] = row['is_enabled'] == true;
        if (row['quiet_hours_start'] != null) _quietStart.text = row['quiet_hours_start'].toString().substring(0, 5);
        if (row['quiet_hours_end'] != null) _quietEnd.text = row['quiet_hours_end'].toString().substring(0, 5);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rows = <Map<String, dynamic>>[];
      for (final category in _categories) {
        for (final channel in _channels) {
          rows.add({
            'profile_id': _userId(ref),
            'category': category,
            'channel': channel,
            'is_enabled': _values['$category|$channel'] ?? true,
            'quiet_hours_start': _quietStart.text.trim().isEmpty ? null : _quietStart.text.trim(),
            'quiet_hours_end': _quietEnd.text.trim().isEmpty ? null : _quietEnd.text.trim(),
            'timezone': 'Africa/Dar_es_Salaam',
          });
        }
      }
      await ref.read(supabaseProvider).from('notification_preferences').upsert(rows, onConflict: 'profile_id,category,channel');
      if (mounted) AppSnackbar.showSuccess(context, 'Notification preferences saved.');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _quietStart.dispose();
    _quietEnd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
                Text('Choose how SafeShift contacts you. Safety alerts should normally stay enabled.', style: TextStyles.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSizes.md),
                for (final category in _categories) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusLabel(category), style: TextStyles.title),
                        for (final channel in _channels)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(_statusLabel(channel), style: TextStyles.body),
                            value: _values['$category|$channel'] ?? true,
                            onChanged: (value) => setState(() => _values['$category|$channel'] = value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                ],
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quiet hours', style: TextStyles.title),
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _quietStart, decoration: const InputDecoration(labelText: 'From (HH:mm)'))),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(child: TextField(controller: _quietEnd, decoration: const InputDecoration(labelText: 'To (HH:mm)'))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save preferences'),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account, privacy, sessions
// ---------------------------------------------------------------------------
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _name = TextEditingController();
  final _display = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _myProfile(ref);
      _name.text = (profile['full_name'] ?? '').toString();
      _display.text = (profile['display_name'] ?? '').toString();
      _email.text = (profile['email'] ?? '').toString();
      _phone.text = (profile['phone'] ?? '').toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await ref.read(supabaseProvider).from('profiles').update({
        'full_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'display_name': _display.text.trim().isEmpty ? null : _display.text.trim(),
      }).eq('id', _userId(ref));
      if (mounted) AppSnackbar.showSuccess(context, 'Profile updated.');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeContact({required bool email}) async {
    final controller = email ? _email : _phone;
    final value = controller.text.trim();
    if (value.isEmpty) return;
    try {
      await ref.read(supabaseProvider).auth.updateUser(
            email ? UserAttributes(email: value) : UserAttributes(phone: value),
          );
      if (mounted) {
        AppSnackbar.showInfo(context, email ? 'Check your inbox to confirm the new email.' : 'Check your SMS for the verification code.');
      }
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _display.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: AppSizes.sm),
                TextFormField(controller: _display, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: AppSizes.sm),
                FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: const Text('Save profile'),
                ),
                const SizedBox(height: AppSizes.lg),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact details', style: TextStyles.title),
                      const SizedBox(height: AppSizes.sm),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: AppSizes.sm),
                      OutlinedButton(onPressed: () => _changeContact(email: true), child: const Text('Update email')),
                      const SizedBox(height: AppSizes.md),
                      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: AppSizes.sm),
                      OutlinedButton(onPressed: () => _changeContact(email: false), child: const Text('Update phone')),
                      const SizedBox(height: AppSizes.sm),
                      Text('Changing a phone or email triggers re-verification before it becomes active.', style: TextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sessions', style: TextStyles.title),
                      const SizedBox(height: AppSizes.sm),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: ref.read(supabaseProvider).from('user_sessions').select('id, device_name, platform, last_seen_at, revoked_at').eq('profile_id', _userId(ref)).order('last_seen_at', ascending: false),
                        builder: (context, snapshot) {
                          final sessions = snapshot.data ?? const <Map<String, dynamic>>[];
                          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                          if (sessions.isEmpty) return Text('No active sessions found.', style: TextStyles.body);
                          return Column(
                            children: sessions.map((session) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.devices_rounded),
                              title: Text((session['device_name'] ?? session['platform'] ?? 'Device').toString(), style: TextStyles.body),
                              subtitle: Text('Last seen ${_date(session['last_seen_at'])}', style: TextStyles.caption),
                            )).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.sm),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(supabaseProvider).auth.signOut(scope: SignOutScope.others);
                          if (context.mounted) AppSnackbar.showSuccess(context, 'Other sessions signed out.');
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out other sessions'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Privacy & data'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/privacy'),
                ),
              ],
            ),
    );
  }
}

class PrivacyDataScreen extends ConsumerWidget {
  const PrivacyDataScreen({super.key});

  Future<void> _request(BuildContext context, WidgetRef ref, String type) async {
    try {
      final client = ref.read(supabaseProvider);
      final requestNumber = generateReferenceNumber('DSR', DateTime.now());
      final row = await client.from('data_subject_requests').insert({
        'request_number': requestNumber,
        'requester_profile_id': _userId(ref),
        'request_type': type,
        'status': 'received',
        'reason': type == 'delete' ? 'Customer requested account deletion from mobile app.' : 'Customer requested a copy of their data.',
      }).select('id').single();
      if (type == 'export') {
        try {
          await client.functions.invoke('data-export', body: {'request_id': row['id']});
        } catch (_) {
          // The request remains queued if the Edge Function is unavailable.
        }
      }
      if (context.mounted) AppSnackbar.showSuccess(context, type == 'delete' ? 'Deletion request submitted.' : 'Export request submitted.');
    } catch (error) {
      if (context.mounted) AppSnackbar.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('data_subject_requests').select('id, request_number, request_type, status, requested_at, completed_at').eq('requester_profile_id', _userId(ref)).order('requested_at', ascending: false),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your data rights', style: TextStyles.title),
                    const SizedBox(height: AppSizes.sm),
                    Text('Request a portable copy of your data or ask us to delete your account. Identity is verified before processing.', style: TextStyles.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSizes.md),
                    FilledButton.icon(onPressed: () => _request(context, ref, 'export'), icon: const Icon(Icons.download_rounded), label: const Text('Request data export')),
                    const SizedBox(height: AppSizes.sm),
                    OutlinedButton.icon(onPressed: () => _request(context, ref, 'delete'), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Request account deletion')),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text('Requests', style: TextStyles.title),
              const SizedBox(height: AppSizes.sm),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (rows.isEmpty)
                const AppEmptyState(icon: Icons.privacy_tip_outlined, title: 'No privacy requests', message: 'Your export and deletion requests will appear here.')
              else
                ...rows.map((row) => Card(
                      child: ListTile(
                        leading: Icon(row['request_type'] == 'delete' ? Icons.delete_outline_rounded : Icons.download_rounded),
                        title: Text(row['request_number'].toString()),
                        subtitle: Text('${_statusLabel(row['request_type'])} · ${_statusLabel(row['status'])}\nRequested ${_date(row['requested_at'])}'),
                        isThreeLine: true,
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disputes
// ---------------------------------------------------------------------------
class DisputesListScreen extends ConsumerWidget {
  const DisputesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disputes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/disputes/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Open dispute'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('disputes').select('id, dispute_type, status, summary, created_at, job_id').eq('raised_by', _userId(ref)).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.gavel_outlined, title: 'No disputes', message: 'Report damage, loss, delay, fare, or safety concerns here.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  title: Text('${_statusLabel(row['dispute_type'])} · ${_statusLabel(row['status'])}'),
                  subtitle: Text('${row['summary']}\n${_date(row['created_at'])}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/disputes/${row['id']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DisputeCreateScreen extends ConsumerStatefulWidget {
  const DisputeCreateScreen({super.key});

  @override
  ConsumerState<DisputeCreateScreen> createState() => _DisputeCreateScreenState();
}

class _DisputeCreateScreenState extends ConsumerState<DisputeCreateScreen> {
  final _summary = TextEditingController();
  final _resolution = TextEditingController();
  String _type = 'damage';
  String? _jobId;
  XFile? _photo;
  bool _saving = false;

  Future<void> _pick() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image != null) setState(() => _photo = image);
  }

  Future<void> _submit() async {
    if (_summary.text.trim().length < 5 || _jobId == null) {
      AppSnackbar.showError(context, 'Choose a job and describe the issue.');
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final dispute = await client.from('disputes').insert({
        'job_id': _jobId,
        'raised_by': _userId(ref),
        'raised_by_role': 'customer',
        'dispute_type': _type,
        'status': 'open',
        'priority': 'normal',
        'summary': _summary.text.trim(),
        'requested_resolution': _resolution.text.trim().isEmpty ? null : _resolution.text.trim(),
      }).select('id').single();
      final disputeId = dispute['id'] as String;
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        final path = 'dispute/$disputeId/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await client.storage.from('job-evidence').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        await client.from('dispute_attachments').insert({
          'dispute_id': disputeId,
          'uploaded_by': _userId(ref),
          'storage_path': path,
          'file_mime_type': 'image/jpeg',
          'file_size_bytes': bytes.length,
        });
      }
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Dispute submitted.');
      context.pushReplacement('/disputes/$disputeId');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    _resolution.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open dispute')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('jobs').select('id, status, created_at').eq('customer_id', _userId(ref)).order('created_at', ascending: false),
        builder: (context, snapshot) {
          final jobs = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _jobId,
                decoration: const InputDecoration(labelText: 'Job *'),
                items: jobs.map((job) => DropdownMenuItem(value: job['id'].toString(), child: Text('${job['id'].toString().substring(0, 8)} · ${_statusLabel(job['status'])}'))).toList(),
                onChanged: (value) => setState(() => _jobId = value),
              ),
              const SizedBox(height: AppSizes.sm),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: const ['damage', 'loss', 'delay', 'rude_behavior', 'fare_dispute', 'no_show', 'safety', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(_statusLabel(value)))).toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _summary, maxLines: 4, decoration: const InputDecoration(labelText: 'What happened? *', alignLabelWithHint: true)),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _resolution, maxLines: 2, decoration: const InputDecoration(labelText: 'What outcome would you like?')),
              const SizedBox(height: AppSizes.sm),
              OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo_camera_outlined), label: Text(_photo == null ? 'Attach a photo' : 'Photo attached')),
              const SizedBox(height: AppSizes.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit dispute'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DisputeDetailScreen extends ConsumerStatefulWidget {
  const DisputeDetailScreen({super.key, required this.disputeId});
  final String disputeId;

  @override
  ConsumerState<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  final _message = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supabaseProvider).from('dispute_messages').insert({
        'dispute_id': widget.disputeId,
        'sender_profile_id': _userId(ref),
        'message': _message.text.trim(),
      });
      _message.clear();
      setState(() {});
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(supabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: client.from('disputes').select('*, dispute_messages(*), dispute_attachments(*)').eq('id', widget.disputeId).single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final dispute = snapshot.data!;
          final messages = (dispute['dispute_messages'] as List?) ?? const [];
          final attachments = (dispute['dispute_attachments'] as List?) ?? const [];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  children: [
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Expanded(child: Text(_statusLabel(dispute['dispute_type']), style: TextStyles.title.copyWith(fontSize: 16))), _Pill(label: _statusLabel(dispute['status']), color: AppColors.warning)]),
                          const SizedBox(height: AppSizes.sm),
                          Text(dispute['summary'].toString(), style: TextStyles.body),
                          if (dispute['requested_resolution'] != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            Text('Requested: ${dispute['requested_resolution']}', style: TextStyles.caption.copyWith(color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.md),
                      Text('Evidence', style: TextStyles.title),
                      const SizedBox(height: AppSizes.sm),
                      ...attachments.map((attachment) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.photo_outlined),
                            title: Text(attachment['storage_path'].toString().split('/').last, style: TextStyles.body),
                            subtitle: Text(_date(attachment['created_at']), style: TextStyles.caption),
                          )),
                    ],
                    const SizedBox(height: AppSizes.md),
                    Text('Conversation', style: TextStyles.title),
                    const SizedBox(height: AppSizes.sm),
                    if (messages.isEmpty)
                      Text('No messages yet.', style: TextStyles.body.copyWith(color: AppColors.textSecondary))
                    else
                      ...messages.map((message) => Align(
                            alignment: message['sender_profile_id'] == _userId(ref) ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: AppSizes.sm),
                              padding: const EdgeInsets.all(AppSizes.sm),
                              constraints: const BoxConstraints(maxWidth: 300),
                              decoration: BoxDecoration(
                                color: message['sender_profile_id'] == _userId(ref) ? AppColors.primaryLight : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Text(message['message'].toString(), style: TextStyles.body),
                            ),
                          )),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _message, decoration: const InputDecoration(hintText: 'Add a message'))),
                      const SizedBox(width: AppSizes.sm),
                      IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Support tickets
// ---------------------------------------------------------------------------
class SupportHomeScreen extends ConsumerWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/support/new'), icon: const Icon(Icons.add_rounded), label: const Text('New ticket')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('support_tickets').select('id, ticket_number, subject, status, priority, created_at, support_categories(name)').eq('opened_by', _userId(ref)).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.support_agent_rounded, title: 'No support tickets', message: 'Open a ticket for account, payment, app, or trip issues.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = row['support_categories'] as Map?;
              return Card(
                child: ListTile(
                  title: Text(row['subject'].toString()),
                  subtitle: Text('${row['ticket_number']} · ${category?['name'] ?? 'Support'} · ${_statusLabel(row['status'])}\n${_date(row['created_at'])}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/support/${row['id']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SupportCreateScreen extends ConsumerStatefulWidget {
  const SupportCreateScreen({super.key});

  @override
  ConsumerState<SupportCreateScreen> createState() => _SupportCreateScreenState();
}

class _SupportCreateScreenState extends ConsumerState<SupportCreateScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _categoryId;
  bool _saving = false;

  Future<void> _submit() async {
    if (_categoryId == null || _subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      AppSnackbar.showError(context, 'Choose a category and fill in the subject and message.');
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final profile = await _myProfile(ref);
      final ticket = await client.from('support_tickets').insert({
        'country_id': profile['default_country_id'],
        'ticket_number': generateReferenceNumber('TKT', DateTime.now()),
        'opened_by': _userId(ref),
        'category_id': _categoryId,
        'subject': _subject.text.trim(),
        'status': 'open',
        'priority': 'normal',
      }).select('id').single();
      await client.from('support_ticket_messages').insert({
        'ticket_id': ticket['id'],
        'sender_profile_id': _userId(ref),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      context.pushReplacement('/support/${ticket['id']}');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New support ticket')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('support_categories').select('id, name, description').eq('is_active', true).order('display_order'),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: categories.map((category) => DropdownMenuItem(value: category['id'].toString(), child: Text(category['name'].toString()))).toList(),
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject *')),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _message, maxLines: 6, decoration: const InputDecoration(labelText: 'Describe the issue *', alignLabelWithHint: true)),
              const SizedBox(height: AppSizes.lg),
              FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.send_rounded), label: const Text('Create ticket')),
            ],
          );
        },
      ),
    );
  }
}

class SupportDetailScreen extends ConsumerStatefulWidget {
  const SupportDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends ConsumerState<SupportDetailScreen> {
  final _message = TextEditingController();
  bool _sending = false;

  Future<void> _reply() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supabaseProvider).from('support_ticket_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_profile_id': _userId(ref),
        'message': _message.text.trim(),
      });
      _message.clear();
      setState(() {});
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(supabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: client.from('support_tickets').select('*, support_categories(name), support_ticket_messages(*)').eq('id', widget.ticketId).single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final ticket = snapshot.data!;
          final messages = (ticket['support_ticket_messages'] as List?) ?? const [];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  children: [
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket['subject'].toString(), style: TextStyles.title.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${ticket['ticket_number']} · ${(ticket['support_categories'] as Map?)?['name'] ?? 'Support'}', style: TextStyles.caption.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: AppSizes.sm),
                          _Pill(label: _statusLabel(ticket['status']), color: AppColors.warning),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    ...messages.map((message) => Align(
                          alignment: message['sender_profile_id'] == _userId(ref) ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSizes.sm),
                            padding: const EdgeInsets.all(AppSizes.sm),
                            constraints: const BoxConstraints(maxWidth: 300),
                            decoration: BoxDecoration(
                              color: message['sender_profile_id'] == _userId(ref) ? AppColors.primaryLight : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(message['message'].toString(), style: TextStyles.body),
                          ),
                        )),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _message, decoration: const InputDecoration(hintText: 'Reply to support'))),
                      const SizedBox(width: AppSizes.sm),
                      IconButton.filled(onPressed: _sending ? null : _reply, icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Safety: emergency contacts, trip share, SOS
// ---------------------------------------------------------------------------
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final relation = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add emergency contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: AppSizes.sm),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: AppSizes.sm),
            TextField(controller: relation, decoration: const InputDecoration(labelText: 'Relationship')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await ref.read(supabaseProvider).from('emergency_contacts').insert({
        'profile_id': _userId(ref),
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'relationship': relation.text.trim().isEmpty ? null : relation.text.trim(),
        'notify_on_trip_start': true,
        'notify_on_sos': true,
      });
      if (context.mounted) AppSnackbar.showSuccess(context, 'Emergency contact added.');
    } catch (error) {
      if (context.mounted) AppSnackbar.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      floatingActionButton: FloatingActionButton(onPressed: () => _add(context, ref), child: const Icon(Icons.add_rounded)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('emergency_contacts').select().eq('profile_id', _userId(ref)).order('is_primary', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.emergency_outlined, title: 'No emergency contacts', message: 'Add someone SafeShift can notify on trip start or when you raise an SOS.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.contact_emergency_outlined),
                  title: Text(row['name'].toString()),
                  subtitle: Text('${row['phone']} · ${row['relationship'] ?? 'Contact'}\nSOS: ${row['notify_on_sos'] == true ? 'on' : 'off'} · Trip start: ${row['notify_on_trip_start'] == true ? 'on' : 'off'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await ref.read(supabaseProvider).from('emergency_contacts').delete().eq('id', row['id']);
                      if (context.mounted) context.pushReplacement('/safety/contacts');
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> shareTrip(BuildContext context, WidgetRef ref, String jobId) async {
  try {
    final client = ref.read(supabaseProvider);
    String? url;
    try {
      final response = await client.functions.invoke('create-trip-share-token', body: {'job_id': jobId});
      final data = response.data;
      if (data is Map && data['share_url'] != null) url = data['share_url'].toString();
    } catch (_) {
      final data = await client.rpc('create_trip_share_token', params: {'p_job_id': jobId});
      final row = data is List && data.isNotEmpty ? data.first : data;
      if (row is Map && row['token'] != null) {
        url = 'http://localhost:3001/trip/${row['token']}';
      }
    }
    if (url == null) throw StateError('Could not create a tracking link.');
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trip link ready'),
          content: Text('Copied to clipboard. Anyone with this link can see live trip status for 24 hours.\n\n$url'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.showError(context, error.toString());
  }
}

Future<void> raiseSos(BuildContext context, WidgetRef ref, String jobId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Raise SOS?'),
      content: const Text('SafeShift will alert your emergency contacts and the on-call safety team. Only use this in a genuine emergency.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Raise SOS'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final client = ref.read(supabaseProvider);
    final alert = await client.from('trip_alerts').insert({
      'job_id': jobId,
      'profile_id': _userId(ref),
      'alert_type': 'sos',
      'status': 'open',
      'details': 'SOS raised from the customer app during an active trip.',
    }).select('id').single();
    try {
      await client.functions.invoke('sos_alert', body: {'alert_id': alert['id']});
    } catch (_) {
      // The alert is still visible to on-call staff if the function is offline.
    }
    if (context.mounted) AppSnackbar.showSuccess(context, 'SOS raised. Safety team and emergency contacts notified.');
  } catch (error) {
    if (context.mounted) AppSnackbar.showError(context, error.toString());
  }
}

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------
class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  Future<void> _rateJob() async {
    final client = ref.read(supabaseProvider);
    final jobs = await client.from('jobs').select('id, driver_id, completed_at, status').eq('customer_id', _userId(ref)).eq('status', 'completed').not('driver_id', 'is', null).order('completed_at', ascending: false).limit(20);
    if (!mounted) return;
    if (jobs.isEmpty) {
      AppSnackbar.showInfo(context, 'No completed trips with a driver to rate yet.');
      return;
    }
    String jobId = jobs.first['id'].toString();
    int score = 5;
    final comment = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate your driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: jobId,
                decoration: const InputDecoration(labelText: 'Trip'),
                items: jobs.map((job) => DropdownMenuItem(value: job['id'].toString(), child: Text('${job['id'].toString().substring(0, 8)} · ${_date(job['completed_at'])}'))).toList(),
                onChanged: (value) => jobId = value ?? jobId,
              ),
              const SizedBox(height: AppSizes.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setDialogState(() => score = index + 1),
                  icon: Icon(index < score ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFB300)),
                )),
              ),
              TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Comment')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      final job = jobs.firstWhere((row) => row['id'].toString() == jobId);
      final category = await client.from('rating_categories').select('id').eq('code', 'overall').eq('applies_to_role', 'customer').maybeSingle();
      if (category == null) throw StateError('Rating category is unavailable.');
      await client.from('ratings').insert({
        'job_id': jobId,
        'rater_profile_id': _userId(ref),
        'rated_profile_id': job['driver_id'],
        'rated_role': 'driver',
        'rating_category_id': category['id'],
        'score': score,
        'comment': comment.text.trim().isEmpty ? null : comment.text.trim(),
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Thanks for your review.');
        setState(() {});
      }
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ratings & reviews')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _rateJob, icon: const Icon(Icons.star_rounded), label: const Text('Rate a trip')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('ratings').select('*, rating_categories(name), jobs(status, completed_at)').or('rater_profile_id.eq.${_userId(ref)},rated_profile_id.eq.${_userId(ref)}').order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.star_outline_rounded, title: 'No reviews yet', message: 'Rate a completed trip to help keep SafeShift reliable.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = row['rating_categories'] as Map?;
              final mine = row['rater_profile_id'] == _userId(ref);
              return Card(
                child: ListTile(
                  leading: Text(row['score'].toString(), style: TextStyles.headline.copyWith(color: const Color(0xFFFFB300))),
                  title: Text('${category?['name'] ?? 'Overall'} · ${mine ? 'You rated' : 'You received'}'),
                  subtitle: Text('${row['comment'] ?? 'No comment'}\n${_date(row['created_at'])}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
