import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  String? _selectedPilotType;
  String? _selectedLicenseType;
  bool _isLoading = false;

  Future<void> _handleSave() async {
    if (_selectedPilotType == null || _selectedLicenseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pilot type and license type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).updateProfile(
          pilotType: _selectedPilotType,
          licenseType: _selectedLicenseType,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                Icons.person_outline_rounded,
                size: 64,
                color: AppColors.primary,
              ).animate()
                .fadeIn(duration: 400.ms)
                .scale(delay: 200.ms),

              const SizedBox(height: 16),

              Text(
                'Tell us about yourself',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              Text(
                'This helps us personalize your experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 300.ms),

              const SizedBox(height: 40),

              // Pilot Type Selection
              Text(
                'Pilot Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ).animate()
                .fadeIn(delay: 400.ms),

              const SizedBox(height: 12),

              Row(
                children: AppConstants.pilotTypes.map((type) {
                  final isSelected = _selectedPilotType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type != AppConstants.pilotTypes.last ? 12 : 0,
                      ),
                      child: _SelectionCard(
                        label: type,
                        icon: type == 'Student'
                            ? Icons.school_outlined
                            : Icons.badge_outlined,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedPilotType = type);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ).animate()
                .fadeIn(delay: 500.ms)
                .slideX(begin: -0.1, end: 0),

              const SizedBox(height: 32),

              // License Type Selection
              Text(
                'License Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ).animate()
                .fadeIn(delay: 600.ms),

              const SizedBox(height: 12),

              Row(
                children: AppConstants.licenseTypes.map((type) {
                  final isSelected = _selectedLicenseType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type != AppConstants.licenseTypes.last ? 12 : 0,
                      ),
                      child: _SelectionCard(
                        label: type,
                        icon: Icons.card_membership_outlined,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedLicenseType = type);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ).animate()
                .fadeIn(delay: 700.ms)
                .slideX(begin: -0.1, end: 0),

              const Spacer(),

              // Continue button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Continue'),
                ),
              ).animate()
                .fadeIn(delay: 800.ms)
                .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
