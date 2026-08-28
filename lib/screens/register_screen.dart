import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';



class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _divisionController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.USER;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _employeeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _divisionController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    print('🎯 === REGISTER SCREEN: Registration Started ===');
    print('📋 Form validation check...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    
    print('✅ Form validation passed');
    print('📝 Collecting form data...');
    print('🆔 Employee ID: ${_employeeIdController.text.trim()}');
    print('👤 Name: ${_nameController.text.trim()}');
    print('📧 Email: ${_emailController.text.trim()}');
    print('📱 Phone: ${_phoneController.text.trim().isEmpty ? 'Not provided' : _phoneController.text.trim()}');
    print('🏢 Division: ${_divisionController.text.trim().isEmpty ? 'Not provided' : _divisionController.text.trim()}');
    print('💼 Designation: ${_designationController.text.trim().isEmpty ? 'Not provided' : _designationController.text.trim()}');
    print('👔 Selected Role: ${_selectedRole.toString().split('.').last}');

    // Haptic feedback
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    print('⏳ Loading state set to true');

    try {
      print('🚀 Calling AuthService.register()...');
      await _authService.register(
        employeeId: _employeeIdController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        division: _divisionController.text.trim().isEmpty ? null : _divisionController.text.trim(),
        designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      print('✅ Registration successful! Checking account status...');
      
      if (mounted) {
        // Success haptic feedback
        HapticFeedback.mediumImpact();
        print('📱 Success haptic feedback triggered');
        
        // Check if account needs approval
        if (!_authService.isAccountApproved) {
          print('⚠️ New account requires approval, showing status dialog');
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('Registration Successful'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your account has been created successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(_authService.getAccountStatusMessage()),
                  const SizedBox(height: 16),
                  const Text(
                    'You will receive an email notification once your account is approved by an administrator.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Logout and go back to login screen
                    _authService.logout();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Account is already approved, navigate to dashboard
          print('✅ Account approved! Navigating to dashboard...');
          
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
        
        print('🎯 === REGISTER SCREEN: Process completed ===');
      }
    } catch (e) {
      print('💥 Registration failed in UI: $e');
      print('🚨 Error type: ${e.runtimeType}');
      
      if (mounted) {
        // Error haptic feedback
        HapticFeedback.heavyImpact();
        print('📱 Error haptic feedback triggered');
        print('📢 Showing error snackbar to user');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Registration failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode ? [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
            ] : [
              const Color(0xFFF8F9FA),
              const Color(0xFFE9ECEF),
              const Color(0xFFDEE2E6),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildRegistrationCard(),
                        const SizedBox(height: 20),
                        _buildLoginLink(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Back Button
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode 
                    ? Colors.white.withOpacity(0.2) 
                    : Colors.black.withOpacity(0.1),
                ),
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildRegistrationCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode 
              ? AppTheme.accentOrange.withOpacity(0.2) 
              : AppTheme.accentOrange.withOpacity(0.15),
            width: 1.5,
          ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3) 
              : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Account',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in your details to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.7) 
                  : Colors.black.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            _buildRegistrationForm(),
            const SizedBox(height: 24),
            _buildRegisterButton(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Employee ID and Name Row
        CustomTextField(
          controller: _employeeIdController,
          label: 'Employee ID',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (value.length < 2) {
              return 'Too short';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        // Email Field
        CustomTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        // Phone Field
        CustomTextField(
          controller: _phoneController,
          label: 'Phone (Optional)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        
        // Division Field
        CustomTextField(
          controller: _divisionController,
          label: 'Division (Optional)',
          icon: Icons.business_outlined,
          validator: (value) {
            // Optional field, no validation required
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        // Designation Field
        CustomTextField(
          controller: _designationController,
          label: 'Designation (Optional)',
          icon: Icons.work_outline,
          validator: (value) {
            // Optional field, no validation required
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        // Role Field
        _buildRoleDropdown(),
        const SizedBox(height: 12),
        
        // Password Fields
        CustomTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: isDarkMode 
                ? Colors.white.withOpacity(0.7) 
                : Colors.black.withOpacity(0.6),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        CustomTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outlined,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: isDarkMode 
                ? Colors.white.withOpacity(0.7) 
                : Colors.black.withOpacity(0.6),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode 
          ? Colors.white.withOpacity(0.05) 
          : Colors.grey.shade50,
        border: Border.all(
          color: isDarkMode 
            ? AppTheme.accentOrange.withOpacity(0.3) 
            : AppTheme.accentOrange.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<UserRole>(
        value: _selectedRole,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        dropdownColor: isDarkMode 
          ? const Color(0xFF2A2A3E) 
          : Colors.white,
        decoration: InputDecoration(
          labelText: 'Role',
          labelStyle: TextStyle(
            color: isDarkMode 
              ? Colors.white.withOpacity(0.7) 
              : Colors.black.withOpacity(0.6),
            fontSize: 12,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentOrange.withOpacity(0.8),
                  AppTheme.accentOrange,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.work_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: UserRole.values.map((role) {
          return DropdownMenuItem(
            value: role,
            child: Text(
              role.toString().split('.').last,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            HapticFeedback.lightImpact();
            setState(() => _selectedRole = value);
          }
        },
      ),
    );
  }

  Widget _buildRegisterButton() {
    return CustomButton(
      text: 'Create Account',
      onPressed: _register,
      isLoading: _isLoading,
      icon: Icons.person_add_rounded,
    );
  }

  Widget _buildLoginLink() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Colors.white.withOpacity(0.05) 
          : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1) 
            : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Already have an account? ",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDarkMode 
                ? Colors.white.withOpacity(0.7) 
                : Colors.black.withOpacity(0.6),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withOpacity(0.1),
                    Colors.red.shade600.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentOrange.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Sign In',
                style: TextStyle(
                  color: AppTheme.accentOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}