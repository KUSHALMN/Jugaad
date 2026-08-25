import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class JobPostingScreen extends StatefulWidget {
  const JobPostingScreen({Key? key}) : super(key: key);

  @override
  State<JobPostingScreen> createState() => _JobPostingScreenState();
}

class _JobPostingScreenState extends State<JobPostingScreen> {
  int _currentStep = 1; // 1, 2, or 3
  
  // State variables for the job
  String _selectedCategory = '';
  bool _isScheduled = false; // false = Right now, true = Schedule for later
  
  final TextEditingController _descController = TextEditingController();

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Final submit
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CustomAppBar(
        title: 'Post a job',
        showBack: true,
        action: Center(
          child: Text(
            'Step $_currentStep/3',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              color: colors.neutralPrimary,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Stepper (3 dots)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              color: colors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(1, colors),
                  const SizedBox(width: 8.0),
                  _buildDot(2, colors),
                  const SizedBox(width: 8.0),
                  _buildDot(3, colors),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildCurrentStep(colors),
                ),
              ),
            ),
            
            // Bottom Action Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: _currentStep == 3 
                    ? (_isScheduled ? 'Schedule job' : 'Post job')
                    : 'Continue',
                onPressed: () {
                  // Basic validation
                  if (_currentStep == 1 && _selectedCategory.isEmpty) {
                    // Show error or return
                    return;
                  }
                  _nextStep();
                },
              ),
            ),
            
            if (_currentStep == 3 && _isScheduled)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, left: 24.0, right: 24.0),
                child: Text(
                  "We'll confirm a worker 2 hours before your slot.",
                  style: TextStyle(
                    fontSize: 11.0,
                    color: colors.neutralPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int stepIndex, AppColors colors) {
    bool isActive = stepIndex <= _currentStep;
    return Container(
      width: 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? colors.primary : colors.neutralBorder,
      ),
    );
  }

  Widget _buildCurrentStep(AppColors colors) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(colors);
      case 2:
        return _buildStep2(colors);
      case 3:
        return _buildStep3(colors);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1 — WHAT + URGENCY
  // ==========================================
  Widget _buildStep1(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you need?',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        
        // 2x2 Category Grid
        Row(
          children: [
            Expanded(child: _buildCategorySelect('Laptop repair', Icons.laptop_mac, colors)),
            const SizedBox(width: 8.0),
            Expanded(child: _buildCategorySelect('Phone repair', Icons.phone_android, colors)),
          ],
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(child: _buildCategorySelect('Electrician', Icons.electrical_services, colors)),
            const SizedBox(width: 8.0),
            Expanded(child: _buildCategorySelect('Plumber', Icons.plumbing, colors)),
          ],
        ),
        const SizedBox(height: 32.0),
        
        // Urgency Toggle Row
        Text(
          'How soon?',
          style: TextStyle(
            fontSize: 12.0,
            color: colors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        Row(
          children: [
            Expanded(
              child: _buildUrgencyPill(
                'Right now', 
                !_isScheduled, 
                colors, 
                () => setState(() => _isScheduled = false),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: _buildUrgencyPill(
                'Schedule for later', 
                _isScheduled, 
                colors, 
                () => setState(() => _isScheduled = true),
              ),
            ),
          ],
        ),
        
        if (_isScheduled) ...[
          const SizedBox(height: 24.0),
          // Inline date+time picker placeholder
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border.all(color: colors.neutralBorder, width: 0.5),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18.0, color: colors.primary),
                    const SizedBox(width: 12.0),
                    const Text('Tomorrow, 10:00 AM', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500)),
                  ],
                ),
                Text('Change', style: TextStyle(color: colors.primary, fontSize: 13.0, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelect(String name, IconData icon, AppColors colors) {
    bool isSelected = _selectedCategory == name;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = name;
        });
      },
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: 80.0,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isSelected ? colors.lightFill : Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? colors.primary : colors.neutralBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24.0, color: isSelected ? colors.primary : colors.neutralPrimary),
            const Spacer(),
            Text(
              name,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.primary : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyPill(String text, bool isSelected, AppColors colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100.0),
          border: Border.all(
            color: isSelected ? colors.primary : colors.neutralBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : colors.neutralPrimary,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2 — DETAILS
  // ==========================================
  Widget _buildStep2(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add details',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        
        CustomTextInput(
          hintText: 'Describe the issue briefly...',
          isMultiline: true,
          controller: _descController,
        ),
        const SizedBox(height: 24.0),
        
        // Location
        Text(
          'Location',
          style: TextStyle(
            fontSize: 12.0,
            color: colors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: colors.neutralFill.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: colors.neutralBorder, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '452, 6th Main, Vijayanagar 1st Stage, Mysuru',
                  style: TextStyle(fontSize: 13.0, height: 1.4),
                ),
              ),
              const SizedBox(width: 16.0),
              Text('Change', style: TextStyle(color: colors.primary, fontSize: 13.0, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 32.0),
        
        // Budget Hint (Amber)
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: colors.warningFill,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: colors.warningBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors.warningPrimary, size: 18.0),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'Workers in your area charge ₹150–₹350 for this',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: colors.warningPrimary, // amber
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 — CONFIRM
  // ==========================================
  Widget _buildStep3(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Confirm',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16.0),
        
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: colors.neutralBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Service', _selectedCategory.isNotEmpty ? _selectedCategory : 'Not selected', colors),
              const Divider(height: 24.0),
              _buildSummaryRow('Urgency', _isScheduled ? 'Scheduled for tomorrow, 10:00 AM' : 'Right now', colors),
              const Divider(height: 24.0),
              _buildSummaryRow('Location', 'Vijayanagar 1st Stage, Mysuru', colors),
              const Divider(height: 24.0),
              _buildSummaryRow('Estimated Cost', '₹150 - ₹350', colors, highlightValue: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, AppColors colors, {bool highlightValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              color: colors.neutralPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: highlightValue ? FontWeight.w700 : FontWeight.w500,
              color: highlightValue ? colors.primary : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
