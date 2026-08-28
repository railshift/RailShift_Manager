import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
  });

  @override
   Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        border: Border.all(color: isDarkMode ? AppTheme.accentOrange.withOpacity(0.3):  AppTheme.accentOrange.withOpacity(0.2),
        width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        obscureText: obscureText,
          style: TextStyle(
            color: isDarkMode ?
                Colors.white : Colors.black87,
            fontSize: 14
          ),
        decoration:
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ?
                Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6),
            fontSize: 12
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.accentOrange.withOpacity(0.8), AppTheme.accentOrange],),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
          ) ,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16,vertical: 16),
          ),
          validator: validator,
        ),
      );
  }
}