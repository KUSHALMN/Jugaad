import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  int _currentStep = 1; // 1 to 4 (4 is Post-Submit)
  
  // Step 1 State
  final TextEditingController _nameController = TextEditingController();
  String? _selectedArea;
  final List<DropdownMenuItem<String>> _pilotAreas = const [
    DropdownMenuItem(value: 'vijayanagar', child: Text('Vijayanagar 1st Stage')),
    DropdownMenuItem(value: 'kuvempunagar', child: Text('Kuvempunagar')),
    DropdownMenuItem(value: 'saraswathipuram', child: Text('Saraswathipuram')),
    DropdownMenuItem(value: 'gokulam', child: Text('Gokulam')),
  ];

  // Step 2 State
  final List<String> _selectedSkills = [];
  final List<String> _availableSkills = [
    'Laptop repair', 'Phone repair', 'Electrician', 
    'Plumber', 'Carpenter', 'AC service'
  ];
  final TextEditingController _rateController = TextEditingController();

  // Step 3 State
  bool _isFileUploaded = false;

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 1 && _currentStep < 4) {
      setState(() {
        _currentStep--;
      });
    } else if (_currentStep == 1) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Override colors for Worker Mode manually since Theme might be mixed depending on entry
    final colors = Theme.of(context).extension<AppColors>()!;
    
    // Hardcoding worker colors as instructed in Phase 1A for reliability if Theme is not swapped yet
    final Color workerPrimary = const Color(0xFF0F6E56);
    final Color workerLightFill = const Color(0xFFE1F5EE);
    
    if (_currentStep == 4) {
      return _buildPostSubmitScreen(colors, workerPrimary, workerLightFill);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: CustomAppBar(
        title: 'Worker Registration',
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
            // Progress Stepper
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              color: colors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(1, workerPrimary, colors.neutralBorder),
                  const SizedBox(width: 8.0),
                  _buildDot(2, workerPrimary, colors.neutralBorder),
                  const SizedBox(width: 8.0),
                  _buildDot(3, workerPrimary, colors.neutralBorder),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildCurrentStep(colors, workerPrimary, workerLightFill),
                ),
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 44.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workerPrimary, // Green
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  ),
                  onPressed: () {
                    // Validations can go here
                    _nextStep();
                  },
                  child: Text(
                    _currentStep == 3 ? 'Submit for approval' : 'Continue',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int stepIndex, Color activeColor, Color inactiveColor) {
    bool isActive = stepIndex <= _currentStep;
    return Container(
      width: 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? activeColor : inactiveColor,
      ),
    );
  }

  Widget _buildCurrentStep(AppColors colors, Color workerPrimary, Color workerLightFill) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(colors);
      case 2:
        return _buildStep2(colors, workerPrimary, workerLightFill);
      case 3:
        return _buildStep3(colors, workerPrimary, workerLightFill);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1 — BASIC INFO
  // ==========================================
  Widget _buildStep1(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic info', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24.0),
        
        const Text('Full Name', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        CustomTextInput(hintText: 'Enter your name', controller: _nameController),
        const SizedBox(height: 24.0),
        
        const Text('Phone Number', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        const CustomTextInput(hintText: '+91 9876543210', isDisabled: true), // Pre-filled from OTP
        const SizedBox(height: 24.0),
        
        const Text('Which area do you work in?', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        CustomDropdown<String>(
          hintText: 'Select pilot zone',
          value: _selectedArea,
          items: _pilotAreas,
          onChanged: (val) => setState(() => _selectedArea = val),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Critical: This is how admin knows where to assign you.',
          style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2 — SKILLS
  // ==========================================
  Widget _buildStep2(AppColors colors, Color workerPrimary, Color workerLightFill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Skills & Pricing', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24.0),
        
        const Text('What skills do you offer?', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _availableSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSkills.remove(skill);
                  } else {
                    _selectedSkills.add(skill);
                  }
                });
              },
              borderRadius: BorderRadius.circular(100.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected ? workerPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(100.0),
                  border: Border.all(
                    color: isSelected ? workerPrimary : colors.neutralBorder,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : colors.neutralPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32.0),
        
        const Text('What do you charge? (₹ per hour)', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        TextField(
          controller: _rateController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 200',
            prefixText: '₹ ',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: workerPrimary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 — ID VERIFICATION
  // ==========================================
  Widget _buildStep3(AppColors colors, Color workerPrimary, Color workerLightFill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verification', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24.0),
        
        // Green info banner
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: workerLightFill,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: workerPrimary.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: workerPrimary, size: 18.0),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  "We'll review and approve you within 24 hours",
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: workerPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32.0),
        
        const Text('Upload Aadhaar / Govt ID', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: () {
            setState(() {
              _isFileUploaded = true; // Mocking upload
            });
          },
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: _isFileUploaded ? workerPrimary : colors.neutralBorder, width: 1.0),
            ),
            child: Column(
              children: [
                Icon(
                  _isFileUploaded ? Icons.check_circle : Icons.upload_file,
                  color: _isFileUploaded ? workerPrimary : colors.neutralPrimary,
                  size: 32.0,
                ),
                const SizedBox(height: 12.0),
                Text(
                  _isFileUploaded ? 'ID uploaded successfully' : 'Tap to upload file',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: _isFileUploaded ? workerPrimary : colors.neutralPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // POST-SUBMIT SCREEN
  // ==========================================
  Widget _buildPostSubmitScreen(AppColors colors, Color workerPrimary, Color workerLightFill) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80.0,
                height: 80.0,
                decoration: BoxDecoration(
                  color: workerLightFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_turned_in, size: 40.0, color: workerPrimary),
              ),
              const SizedBox(height: 32.0),
              
              Text(
                'Application submitted!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 16.0),
              
              // The critical manual ops expectation
              Text(
                "We'll call to verify you and explain how jobs work.",
                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              
              Text(
                'Keep your phone nearby. Usually within 24 hours.',
                style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 64.0),
              
              SizedBox(
                width: double.infinity,
                height: 44.0,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: workerPrimary,
                    side: BorderSide(color: workerPrimary, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  ),
                  onPressed: () {
                    // Navigate to splash or empty state
                  },
                  child: const Text('Back to start', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
