import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import 'reset_password_screen.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String gmail; // Renamed for standard naming

  const VerificationCodeScreen({super.key, required this.gmail});

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleVerifyCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simulate API call to verify code
      await Future.delayed(const Duration(seconds: 1));

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(gmail: widget.gmail),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Iconsax.key,
                      color: AppTheme.primaryColor,
                      size: 40,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Center(
                  child: Text(
                    'Verifikasi Kode',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Masukkan kode verifikasi yang telah dikirim ke\n${widget.gmail}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

                const SizedBox(height: 48),

                // Code Field
                Text(
                  'Kode Verifikasi',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '0000',
                    hintStyle: TextStyle(
                      color: AppTheme.textLight.withOpacity(0.5),
                      letterSpacing: 8,
                    ),
                    prefixIcon: const Icon(
                      Iconsax.key,
                      color: AppTheme.textLight,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kode tidak boleh kosong';
                    }
                    if (value.length < 4) {
                      return 'Kode minimal 4 digit';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Verify Button
                CustomButton(
                  text: 'Verifikasi',
                  onPressed: _handleVerifyCode,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Resend Code
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tidak menerima kode? ',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Kode verifikasi telah dikirim ulang!',
                              ),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        },
                        child: const Text(
                          'Kirim Ulang',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
