import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/gmail_validator.dart';
import 'verification_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gmailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _gmailController.dispose();
    super.dispose();
  }

  void _handleForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Sanitize input
      final email = GmailValidator.normalize(_gmailController.text);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationCodeScreen(gmail: email),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Iconsax.lock_1,
                      color: AppTheme.primaryColor,
                      size: 40,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Center(
                  child: Text(
                    'Lupa Password?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Masukkan gmail yang terdaftar untuk\nmendapatkan kode verifikasi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

                const SizedBox(height: 48),

                // Gmail Field
                Text(
                  'Gmail',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _gmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Masukkan gmail anda',
                    prefixIcon: const Icon(
                      Iconsax.sms,
                      color: AppTheme.textLight,
                    ),
                  ),
                  validator: GmailValidator.validate,
                ),

                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: 'Kirim Kode Verifikasi',
                  onPressed: _handleForgotPassword,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
