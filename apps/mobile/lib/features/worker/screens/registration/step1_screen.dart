import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'worker_registration_state.dart';

import 'package:jugaad_mvp/core/services/auth_service.dart';

class WorkerRegistrationStep1 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep1({super.key});

  @override
  ConsumerState<WorkerRegistrationStep1> createState() => _WorkerRegistrationStep1State();
}

class _WorkerRegistrationStep1State extends ConsumerState<WorkerRegistrationStep1> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  final List<String> _categories = [
    'Plumber',
    'Electrician',
    'Carpenter',
    'Laptop repair',
    'Phone repair',
    'AC service',
  ];
  String? _selectedCategory;
  bool _autovalidate = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(workerRegistrationProvider);
    if (state.fullName.isNotEmpty) {
      _nameController.text = state.fullName;
    }
    if (state.phoneNumber.isNotEmpty) {
      _phoneController.text = state.phoneNumber;
    } else {
      final userPhone = AuthService().currentUser?.phoneNumber;
      if (userPhone != null && userPhone.isNotEmpty) {
        _phoneController.text = userPhone.replaceAll('+91', '').trim();
      }
    }
    if (state.workCategory.isNotEmpty && _categories.contains(state.workCategory)) {
      _selectedCategory = state.workCategory;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-\+]'), '');
    final phone = cleaned.startsWith('91') && cleaned.length == 12 ? cleaned.substring(2) : cleaned;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  void _next() {
    setState(() => _autovalidate = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a work category'),
          backgroundColor: AppColors.kDanger,
        ),
      );
      return;
    }

    ref.read(workerRegistrationProvider.notifier).setStep1(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _selectedCategory!,
    );
    context.push('/worker/register/step2');
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _nameController.text.trim().length >= 2 &&
        _isValidPhone(_phoneController.text.trim()) &&
        _selectedCategory != null;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Basic Information',
            currentStep: 1,
            totalSteps: 3,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/splash');
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Full Name',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: AppColors.kTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Ravi Kumar',
                        hintStyle: const TextStyle(color: AppColors.kTextTertiary),
                        filled: true,
                        fillColor: AppColors.kSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Phone Number',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.kTextPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Text('+91', style: TextStyle(color: AppColors.kTextPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '10-digit mobile number',
                        hintStyle: const TextStyle(color: AppColors.kTextTertiary),
                        filled: true,
                        fillColor: AppColors.kSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (!_isValidPhone(value.trim())) {
                          return 'Enter a valid 10-digit Indian phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Work Category',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select your primary skill / trade.',
                      style: TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                          selectedColor: AppColors.kWorkerPrimary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.kWorkerPrimary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.kWorkerPrimary : AppColors.kTextPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.kWorkerPrimary : AppColors.kBorder,
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          backgroundColor: AppColors.kSurface,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ElevatedButton(
              onPressed: isValid ? _next : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kWorkerPrimary,
                disabledBackgroundColor: AppColors.kWorkerPrimary.withValues(alpha: 0.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Next: Upload Photos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
