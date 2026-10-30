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
import '../../auth/providers/auth_provider.dart';

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
// Driver onboarding and verification
// ---------------------------------------------------------------------------
class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenceNumber = TextEditingController();
  final _nationalId = TextEditingController();
  final _registration = TextEditingController();
  final _capacity = TextEditingController(text: '1000');
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _insuranceProvider = TextEditingController();
  final _insurancePolicy = TextEditingController();
  final Map<String, XFile?> _documents = {
    'national_id': null,
    'driving_licence': null,
    'vehicle_registration': null,
    'insurance_certificate': null,
  };
  DateTime? _licenceExpiry;
  DateTime? _insuranceExpiry;
  String? _vehicleTypeId;
  String? _countryId;
  String? _cityId;
  List<Map<String, dynamic>> _vehicleTypes = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(supabaseProvider);
      final profile = await _myProfile(ref);
      _countryId = profile['default_country_id'] as String?;
      if (_countryId != null) {
        final city = await client.from('cities').select('id').eq('country_id', _countryId!).limit(1).maybeSingle();
        _cityId = city?['id'] as String?;
      }
      final types = await client.from('vehicle_types').select('id, name, code').eq('is_active', true).order('display_order');
      _vehicleTypes = types.map((row) => Map<String, dynamic>.from(row)).toList();
      _vehicleTypeId = _vehicleTypes.isNotEmpty ? _vehicleTypes.first['id'].toString() : null;
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument(String code) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 2200);
    if (picked != null) setState(() => _documents[code] = picked);
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now().add(const Duration(days: 365)),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehicleTypeId == null || _countryId == null) {
      AppSnackbar.showError(context, 'Vehicle type and country are required. Contact support if your profile has no country.');
      return;
    }
    if (_licenceExpiry == null || _insuranceExpiry == null) {
      AppSnackbar.showError(context, 'Add your licence and insurance expiry dates.');
      return;
    }
    if (_documents.values.any((file) => file == null)) {
      AppSnackbar.showError(context, 'Upload your ID, licence, vehicle registration, and insurance certificate.');
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      final uid = _userId(ref);
      final documentTypes = await client
          .from('document_types')
          .select('id, code')
          .eq('is_active', true)
          .inFilter('applies_to', ['driver', 'vehicle', 'both']);
      final typeIds = <String, String>{
        for (final row in documentTypes) row['code'].toString(): row['id'].toString(),
      };

      await client.from('drivers').insert({
        'id': uid,
        'country_id': _countryId,
        'home_city_id': _cityId,
        'licence_number': _licenceNumber.text.trim(),
        'licence_expiry': _licenceExpiry!.toIso8601String().split('T').first,
        'licence_country_id': _countryId,
        'verification_status': 'pending',
      });

      final vehicle = await client
          .from('vehicles')
          .insert({
            'country_id': _countryId,
            'home_city_id': _cityId,
            'primary_driver_id': uid,
            'owner_type': 'individual',
            'owner_profile_id': uid,
            'vehicle_type_id': _vehicleTypeId,
            'registration_number': _registration.text.trim().toUpperCase(),
            'registration_country_id': _countryId,
            'capacity_kg': double.tryParse(_capacity.text.trim()) ?? 1000,
            'make_id': null,
            'model_id': null,
            'year': int.tryParse(_year.text.trim()),
            'color': _color.text.trim().isEmpty ? null : _color.text.trim(),
            'verification_status': 'pending',
          })
          .select('id')
          .single();
      final vehicleId = vehicle['id'] as String;

      final driverCodes = ['national_id', 'driving_licence'];
      final vehicleCodes = ['vehicle_registration', 'insurance_certificate'];
      final numbers = <String, String?>{
        'national_id': _nationalId.text.trim(),
        'driving_licence': _licenceNumber.text.trim(),
        'vehicle_registration': _registration.text.trim(),
        'insurance_certificate': _insurancePolicy.text.trim(),
      };
      final expiries = <String, DateTime?>{
        'national_id': null,
        'driving_licence': _licenceExpiry,
        'vehicle_registration': null,
        'insurance_certificate': _insuranceExpiry,
      };

      for (final code in [...driverCodes, ...vehicleCodes]) {
        final file = _documents[code]!;
        final bytes = await file.readAsBytes();
        final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
        final isDriverDoc = driverCodes.contains(code);
        final folder = isDriverDoc ? uid : vehicleId;
        final bucket = isDriverDoc ? 'driver-documents' : 'vehicle-documents';
        final path = '$folder/${DateTime.now().microsecondsSinceEpoch}_$code.$extension';
        await client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg', upsert: false),
            );
        final typeId = typeIds[code];
        if (typeId == null) continue;
        await client.from(isDriverDoc ? 'driver_documents' : 'vehicle_documents').insert({
          if (isDriverDoc) 'driver_id': uid else 'vehicle_id': vehicleId,
          'document_type_id': typeId,
          'document_number': numbers[code]?.isEmpty == true ? null : numbers[code],
          'expires_at': expiries[code]?.toIso8601String().split('T').first,
          'file_path': path,
          'file_mime_type': file.mimeType ?? 'image/jpeg',
          'file_size_bytes': bytes.length,
          'verification_status': 'pending',
        });
      }

      await client.from('verification_requests').insert({
        'request_type': 'driver_verification',
        'driver_id': uid,
        'requested_by': uid,
        'status': 'pending',
        'priority': 'normal',
      });
      await client.from('verification_requests').insert({
        'request_type': 'vehicle_verification',
        'vehicle_id': vehicleId,
        'requested_by': uid,
        'status': 'pending',
        'priority': 'normal',
      });

      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Application submitted. You can go online after verification.');
      context.go('/home');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_licenceNumber, _nationalId, _registration, _capacity, _make, _model, _year, _color, _insuranceProvider, _insurancePolicy]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _documentTile(String code, String label, IconData icon) {
    final file = _documents[code];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Icon(icon, color: file == null ? AppColors.textSecondary : AppColors.success),
        title: Text(label, style: TextStyles.title),
        subtitle: Text(file == null ? 'Not uploaded' : file.name, style: TextStyles.caption),
        trailing: TextButton(onPressed: () => _pickDocument(code), child: Text(file == null ? 'Upload' : 'Replace')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Get verified to drive', style: TextStyles.headline.copyWith(fontSize: 20)),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          'Upload your identity and vehicle documents. SafeShift staff review them before you can go online.',
                          style: TextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  const Text('Identity & licence', style: TextStyles.title),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _nationalId, decoration: const InputDecoration(labelText: 'National ID number *'), validator: (v) => (v ?? '').trim().isEmpty ? 'National ID is required' : null),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _licenceNumber, decoration: const InputDecoration(labelText: 'Driving licence number *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Licence number is required' : null),
                  const SizedBox(height: AppSizes.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Licence expiry *'),
                    subtitle: Text(_licenceExpiry == null ? 'Choose a date' : _licenceExpiry!.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final value = await _pickDate(_licenceExpiry);
                      if (value != null) setState(() => _licenceExpiry = value);
                    },
                  ),
                  _documentTile('national_id', 'National ID photo *', Icons.badge_outlined),
                  _documentTile('driving_licence', 'Driving licence photo *', Icons.drive_eta_outlined),
                  const SizedBox(height: AppSizes.md),
                  const Text('Vehicle', style: TextStyles.title),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _vehicleTypeId,
                    decoration: const InputDecoration(labelText: 'Vehicle type *'),
                    items: _vehicleTypes.map((row) => DropdownMenuItem(value: row['id'].toString(), child: Text(row['name'].toString()))).toList(),
                    onChanged: (value) => setState(() => _vehicleTypeId = value),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _registration, decoration: const InputDecoration(labelText: 'Registration / plate number *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Registration number is required' : null),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity (kg) *'), validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Enter a positive capacity' : null),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _make, decoration: const InputDecoration(labelText: 'Make'))),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Model'))),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year'))),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'Colour'))),
                    ],
                  ),
                  _documentTile('vehicle_registration', 'Vehicle registration photo *', Icons.description_outlined),
                  const SizedBox(height: AppSizes.md),
                  const Text('Insurance', style: TextStyles.title),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _insuranceProvider, decoration: const InputDecoration(labelText: 'Insurance provider *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Insurance provider is required' : null),
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(controller: _insurancePolicy, decoration: const InputDecoration(labelText: 'Policy number *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Policy number is required' : null),
                  const SizedBox(height: AppSizes.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Insurance expiry *'),
                    subtitle: Text(_insuranceExpiry == null ? 'Choose a date' : _insuranceExpiry!.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final value = await _pickDate(_insuranceExpiry);
                      if (value != null) setState(() => _insuranceExpiry = value);
                    },
                  ),
                  _documentTile('insurance_certificate', 'Insurance certificate photo *', Icons.verified_user_outlined),
                  const SizedBox(height: AppSizes.lg),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.verified_user_outlined),
                    label: const Text('Submit for verification'),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'You can browse the app while pending, but you cannot go online or receive jobs until both driver and vehicle checks pass.',
                    textAlign: TextAlign.center,
                    style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
    );
  }
}

class DriverVerificationStatusScreen extends ConsumerWidget {
  const DriverVerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final status = auth.driverVerificationStatus ?? 'pending';
    final color = status == 'verified' ? AppColors.success : status == 'rejected' ? AppColors.error : AppColors.warning;
    return Scaffold(
      appBar: AppBar(title: const Text('Verification status')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text('Driver account', style: TextStyles.title.copyWith(fontSize: 16))), _Pill(label: _statusLabel(status), color: color)]),
                const SizedBox(height: AppSizes.sm),
                Text(
                  status == 'verified'
                      ? 'You are verified. Keep your documents current to stay eligible for jobs.'
                      : status == 'rejected'
                          ? 'Your application was rejected. Open Documents to re-upload the affected files, then contact support.'
                          : 'Your documents are in the review queue. You cannot go online until an admin approves them.',
                  style: TextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          FilledButton.icon(onPressed: () => context.push('/documents'), icon: const Icon(Icons.badge_outlined), label: const Text('View documents')),
          const SizedBox(height: AppSizes.sm),
          OutlinedButton.icon(onPressed: () => context.push('/support'), icon: const Icon(Icons.support_agent_rounded), label: const Text('Contact verification support')),
        ],
      ),
    );
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
                Text('Choose how SafeShift contacts you. Job and safety alerts are strongly recommended.', style: TextStyles.body.copyWith(color: AppColors.textSecondary)),
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
                      const Text('Quiet hours', style: TextStyles.title),
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
                FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save preferences')),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account settings and privacy
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
    final value = (email ? _email : _phone).text.trim();
    if (value.isEmpty) return;
    try {
      await ref.read(supabaseProvider).auth.updateUser(email ? UserAttributes(email: value) : UserAttributes(phone: value));
      if (mounted) AppSnackbar.showInfo(context, email ? 'Check your inbox to confirm the new email.' : 'Check your SMS for the verification code.');
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
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: AppSizes.sm),
                TextField(controller: _display, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: AppSizes.sm),
                FilledButton(onPressed: _saving ? null : _saveProfile, child: const Text('Save profile')),
                const SizedBox(height: AppSizes.lg),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contact details', style: TextStyles.title),
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
      await client.from('data_subject_requests').insert({
        'request_number': generateReferenceNumber('DSR', DateTime.now()),
        'requester_profile_id': _userId(ref),
        'request_type': type,
        'status': 'received',
        'reason': type == 'delete' ? 'Driver requested account deletion from mobile app.' : 'Driver requested a copy of their data.',
      });
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
        future: ref.read(supabaseProvider).from('data_subject_requests').select('id, request_number, request_type, status, requested_at').eq('requester_profile_id', _userId(ref)).order('requested_at', ascending: false),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your data rights', style: TextStyles.title),
                    const SizedBox(height: AppSizes.sm),
                    Text('Request a copy of your data or ask us to delete your account. Identity is verified before processing.', style: TextStyles.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSizes.md),
                    FilledButton.icon(onPressed: () => _request(context, ref, 'export'), icon: const Icon(Icons.download_rounded), label: const Text('Request data export')),
                    const SizedBox(height: AppSizes.sm),
                    OutlinedButton.icon(onPressed: () => _request(context, ref, 'delete'), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Request account deletion')),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const Text('Requests', style: TextStyles.title),
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/disputes/new'), icon: const Icon(Icons.add_rounded), label: const Text('Open dispute')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(supabaseProvider).from('disputes').select('id, dispute_type, status, summary, created_at, job_id').eq('raised_by', _userId(ref)).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return AppErrorView(error: snapshot.error!);
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.gavel_outlined, title: 'No disputes', message: 'Report fare, cargo, damage, delay, or safety concerns here.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
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
  String _type = 'fare_dispute';
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
        'raised_by_role': 'driver',
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
        future: ref.read(supabaseProvider).from('jobs').select('id, status, created_at').eq('driver_id', _userId(ref)).order('created_at', ascending: false),
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
                items: const ['fare_dispute', 'damage', 'loss', 'delay', 'rude_behavior', 'no_show', 'safety', 'other'].map((value) => DropdownMenuItem(value: value, child: Text(_statusLabel(value)))).toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _summary, maxLines: 4, decoration: const InputDecoration(labelText: 'What happened? *', alignLabelWithHint: true)),
              const SizedBox(height: AppSizes.sm),
              TextField(controller: _resolution, maxLines: 2, decoration: const InputDecoration(labelText: 'What outcome would you like?')),
              const SizedBox(height: AppSizes.sm),
              OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo_camera_outlined), label: Text(_photo == null ? 'Attach a photo' : 'Photo attached')),
              const SizedBox(height: AppSizes.lg),
              FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.send_rounded), label: const Text('Submit dispute')),
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
                      const Text('Evidence', style: TextStyles.title),
                      ...attachments.map((attachment) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.photo_outlined),
                            title: Text(attachment['storage_path'].toString().split('/').last, style: TextStyles.body),
                            subtitle: Text(_date(attachment['created_at']), style: TextStyles.caption),
                          )),
                    ],
                    const SizedBox(height: AppSizes.md),
                    const Text('Conversation', style: TextStyles.title),
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
                  padding: const EdgeInsets.all(AppSizes.sm),
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
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.support_agent_rounded, title: 'No support tickets', message: 'Open a ticket for verification, payment, app, or trip issues.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(supabaseProvider).from('support_tickets').select('*, support_categories(name), support_ticket_messages(*)').eq('id', widget.ticketId).single(),
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
// Safety: emergency contacts, trip sharing, SOS
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
          if (rows.isEmpty) return const AppEmptyState(icon: Icons.emergency_outlined, title: 'No emergency contacts', message: 'Add someone SafeShift can notify when you start a trip or raise an SOS.');
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
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
      if (row is Map && row['token'] != null) url = 'http://localhost:3001/trip/${row['token']}';
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
      'details': 'SOS raised from the driver app during an active trip.',
    }).select('id').single();
    try {
      await client.functions.invoke('sos_alert', body: {'alert_id': alert['id']});
    } catch (_) {
      // The alert remains visible to on-call staff if the function is offline.
    }
    if (context.mounted) AppSnackbar.showSuccess(context, 'SOS raised. Safety team and emergency contacts notified.');
  } catch (error) {
    if (context.mounted) AppSnackbar.showError(context, error.toString());
  }
}
