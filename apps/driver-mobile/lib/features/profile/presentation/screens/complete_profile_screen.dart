import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../shared/mock/mock_driver.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Forced first step after OTP when the driver has no profile.
///
/// The form collects the minimum profile fields. Real backend persistence
/// will replace the mock [DriverProfileState.setProfile] call later.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _zoneController;
  String _vehicleClass = 'Pickup';
  bool _saving = false;

  static const _vehicleOptions = <String>[
    'Pickup',
    'Box Truck',
    'Van',
    'Motorbike',
  ];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final phone = auth.currentUser?.phone ?? auth.phoneNumber ?? '';
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _zoneController = TextEditingController();
    // Keep phone for the saved profile; shown read-only below.
    _phoneForProfile = phone;
  }

  String _phoneForProfile = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;
    setState(() => _saving = true);
    // Mock save delay — replaced by a real API call later.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final phone = _phoneForProfile.trim().isEmpty
        ? (ref.read(authProvider).phoneNumber ?? '')
        : _phoneForProfile.trim();
    ref.read(driverProfileStateProvider.notifier).setProfile(
          DriverProfile(
            id: 'driver-001',
            fullName: _nameController.text.trim(),
            phone: phone.isEmpty ? '+255' : '+255$phone',
            email: _emailController.text.trim(),
            rating: 5.0,
            completedTrips: 0,
            verified: false,
            vehicleClass: _vehicleClass,
            zone: _zoneController.text.trim(),
          ),
        );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final phoneLabel = authState.currentUser?.phone ??
        (authState.phoneNumber != null ? '+255${authState.phoneNumber}' : '');

    // Block back navigation: profile must be completed before proceeding.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Complete your profile'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Step 1 of onboarding · Profile${phoneLabel.isNotEmpty ? ' · $phoneLabel' : ''}',
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  const Text('Tell us about yourself',
                      style: TextStyles.headline),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'Complete your profile to start driving with SafeShift.',
                    style: TextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSizes.md),
                  AppTextField(
                    controller: _nameController,
                    labelText: 'Full name',
                    hintText: 'e.g. Baraka Mwansa',
                    keyboardType: TextInputType.name,
                    validator: (v) =>
                        (v == null || v.trim().length < 3)
                            ? 'Enter your full name'
                            : null,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  AppTextField(
                    controller: _emailController,
                    labelText: 'Email (optional)',
                    hintText: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(v.trim())
                          ? null
                          : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: AppSizes.sm),
                  AppTextField(
                    controller: _zoneController,
                    labelText: 'Operating zone',
                    hintText: 'e.g. Kinondoni',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Enter your zone'
                            : null,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _vehicleClass,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle class',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: _vehicleOptions
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _vehicleClass = v);
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    height: AppSizes.buttonHeight,
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Save & continue',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
