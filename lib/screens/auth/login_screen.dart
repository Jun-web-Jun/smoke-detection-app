import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 로그인 화면 (관리자/보안요원 로그인)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 로그인 처리
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 로그인 처리 (1초 대기)
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      // 계정 확인
      final id = _idController.text.trim();
      final password = _passwordController.text;

      if ((id == '20191590' && password == 'fnal@6239') ||
          (id == '1111' && password == '1111')) {
        // 로그인 성공
        context.go('/home');
      } else {
        // 로그인 실패
        setState(() {
          _isLoading = false;
        });

        // 에러 다이얼로그 표시
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            title: const Text('로그인 실패'),
            content: const Text(
              '정보가 일치하지 않습니다.\n다시 한 번 확인해주세요.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F2027),
                    const Color(0xFF203A43),
                    const Color(0xFF2C5364),
                  ]
                : [
                    const Color(0xFF1E3C72),
                    const Color(0xFF2A5298),
                    const Color(0xFF7474BF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 상단 CCTV 일러스트레이션
                    _buildHeaderSection(),
                    const SizedBox(height: 48),

                    // 로그인 카드
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF1A1A2E),
                                    const Color(0xFF16213E),
                                  ]
                                : [
                                    Colors.white,
                                    Colors.grey.shade50,
                                  ],
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // 제목
                              Text(
                                'ADMIN LOGIN',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: isDark ? Colors.cyan : const Color(0xFF1E3C72),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '관리자 로그인',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ID 입력 필드
                              _buildTextField(
                                controller: _idController,
                                label: '아이디',
                                hint: 'ID를 입력하세요',
                                icon: Icons.person_outline,
                                isDark: isDark,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 20),

                              // 비밀번호 입력 필드
                              _buildPasswordField(isDark),
                              const SizedBox(height: 32),

                              // 로그인 버튼
                              _buildLoginButton(isDark),
                              const SizedBox(height: 24),

                              // 보안 안내
                              _buildSecurityNote(isDark),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 하단 정보
                    _buildFooter(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 헤더 섹션 (CCTV 아이콘 + 제목)
  Widget _buildHeaderSection() {
    return Column(
      children: [
        // CCTV 아이콘 애니메이션
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.cyan.withOpacity(0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyan.withOpacity(0.3),
            ),
            child: const Icon(
              Icons.videocam,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          '금연구역 모니터링 시스템',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          'AI-Based Real-time Smoking Detection',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 텍스트 필드
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required TextInputAction textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.cyan),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.cyan.withOpacity(0.3) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.cyan,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label를 입력해주세요';
        }
        return null;
      },
      textInputAction: textInputAction,
    );
  }

  /// 비밀번호 필드
  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: '비밀번호',
        hintText: 'Password를 입력하세요',
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyan),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.cyan.withOpacity(0.3) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.cyan,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력해주세요';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  /// 로그인 버튼
  Widget _buildLoginButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyan,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 보안 안내
  Widget _buildSecurityNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.security,
            size: 18,
            color: Colors.cyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '보안 시스템 - 인증된 사용자만 접근 가능',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.cyan.shade200 : Colors.cyan.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 푸터
  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 16,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Secure Connection',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 Smoke Detection System',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
