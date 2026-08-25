import 'package:flutter/material.dart';
import 'dart:async';
import 'theme.dart';
import 'components.dart';

class OtpAuthScreen extends StatefulWidget {
  final String role; // 'user' or 'worker'

  const OtpAuthScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<OtpAuthScreen> createState() => _OtpAuthScreenState();
}

class _OtpAuthScreenState extends State<OtpAuthScreen> with SingleTickerProviderStateMixin {
  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _hasError = false;
  
  // Phone controller
  final TextEditingController _phoneController = TextEditingController();
  
  // OTP controllers (6 boxes)
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Countdown timer
  int _countdown = 30;
  Timer? _timer;

  // Shake animation for error
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _countdown = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _sendOtp() {
    if (_phoneController.text.length < 10) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Simulate network delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _isOtpSent = true;
      });
      _startTimer();
      // Auto-focus first OTP box
      FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
    });
  }

  void _verifyOtp() {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Simulate network delay
    Future.delayed(const Duration(seconds: 1), () {
      if (otp == "123456") { // Fake success condition
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
        
        // Transition to role-specific home
        Future.delayed(const Duration(milliseconds: 800), () {
          // Navigator.pushReplacement(...) -> would go to UserHome or WorkerHome
        });
      } else { // Fake error condition
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        _shakeController.forward();
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
        // Auto verify when last digit is entered
        _verifyOtp();
      }
    } else {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: '',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16.0),
              
              // Header
              Text(
                'Verify your number',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                _isOtpSent 
                    ? 'Enter the 6-digit code sent to +91 ${_phoneController.text}'
                    : 'We\'ll send you a 6-digit verification code.',
                style: TextStyle(
                  fontSize: 14.0,
                  color: colors.neutralPrimary,
                ),
              ),
              const SizedBox(height: 32.0),

              // Dynamic content based on state
              _isOtpSent ? _buildOtpEntry(colors) : _buildPhoneEntry(colors),
              
              const Spacer(),
              
              // CTA Button
              PrimaryButton(
                text: _isOtpSent ? 'Verify OTP' : 'Send OTP',
                isLoading: _isLoading,
                isSuccess: _isSuccess,
                onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneEntry(AppColors colors) {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.neutralBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // +91 Country Code Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.neutralFill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.0),
                bottomLeft: Radius.circular(8.0),
              ),
              border: Border(right: BorderSide(color: colors.neutralBorder, width: 0.5)),
            ),
            child: const Text(
              '+91',
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
            ),
          ),
          
          // Phone Input
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                hintText: 'Mobile number',
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpEntry(AppColors colors) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: _hasError ? colors.dangerFill : Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _hasError ? colors.dangerPrimary : colors.neutralBorder,
                        width: _hasError ? 1.5 : 0.5,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w600,
                          color: _hasError ? colors.dangerPrimary : Colors.black,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) => _onOtpChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24.0),
              
              // Resend Text
              _countdown > 0
                  ? Text(
                      'Resend OTP in 00:${_countdown.toString().padLeft(2, '0')}',
                      style: TextStyle(color: colors.neutralPrimary, fontSize: 13.0),
                    )
                  : TextButton(
                      onPressed: () {
                        // Reset and resend
                        _startTimer();
                        setState(() {
                          _hasError = false;
                        });
                        for (var c in _otpControllers) {
                          c.clear();
                        }
                        FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
                      },
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
            ],
          ),
        );
      }
    );
  }
}
