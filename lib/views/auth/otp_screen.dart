import 'package:flutter/material.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../services/role_router.dart';

class OtpScreen extends StatefulWidget {
  final String username;

  const OtpScreen({super.key, required this.username});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = VerifyOtpRequest(
      username: widget.username,
      otpCode: _otpController.text.trim(),
    );

    final result = await AuthService.verifyOtp(request);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final userRole = result.data!.role;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xác thực thành công! Quyền: ${userRole ?? "Customer"}'),
          backgroundColor: Colors.green,
        ),
      );

      // Điều hướng theo phân quyền (Câu 3: Role-based navigation)
      RoleRouter.navigateByRole(context, userRole);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Mã OTP không hợp lệ hoặc đã hết hạn.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() => _isResending = true);

    final result = await AuthService.loginStep1(
      LoginStep1Request(username: widget.username, password: ''),
    );

    setState(() => _isResending = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Mã OTP mới đã được gửi lại!'
              : (result.errorMessage ?? 'Gửi lại OTP thất bại, vui lòng đăng nhập lại.'),
        ),
        backgroundColor: result.isSuccess ? Colors.blueAccent : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực OTP'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nhập Mã OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mã xác nhận 6 số đã được gửi đến email liên kết với tài khoản:\n${widget.username}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Ô nhập OTP
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '------',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mã OTP';
                      if (v.trim().length != 6) return 'Mã OTP phải gồm 6 chữ số';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Nút Xác thực
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleVerifyOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'XÁC NHẬN VÀ ĐĂNG NHẬP',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gửi lại mã OTP
                  TextButton.icon(
                    onPressed: _isResending ? null : _handleResendOtp,
                    icon: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Gửi lại mã OTP'),
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
