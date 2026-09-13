import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';

class LoginScreen extends StatefulWidget {
  final AppSession session;
  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _obscure = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_login.text.trim().isEmpty || _password.text.isEmpty) return;
    await widget.session.login(_login.text.trim(), _password.text, remember: _remember);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: AnimatedBuilder(
            animation: widget.session,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.panel2,
                      border: Border.all(color: AppTheme.cyan.withOpacity(.25)),
                      boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(.16), blurRadius: 34)],
                    ),
                    child: const Icon(Icons.sensors, color: AppTheme.cyan, size: 58),
                  ),
                  const SizedBox(height: 24),
                  const Text('VISIONSEN', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                  const SizedBox(height: 4),
                  const Text('ORTAM İZLEME', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  const SizedBox(height: 38),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hesabınıza Giriş Yapın', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 7),
                        const Text('Binalarınızı, odalarınızı ve cihazlarınızı izlemek veya cihaz yapılandırmak için giriş yapın.', style: TextStyle(color: AppTheme.muted, height: 1.45)),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _login,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Kullanıcı adı veya e-posta', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                            const Text('Oturumu açık tut'),
                          ],
                        ),
                        if (widget.session.error != null) ...[
                          const SizedBox(height: 6),
                          Text(widget.session.error!, style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 18),
                        PrimaryButton(
                          text: widget.session.busy ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP',
                          icon: widget.session.busy ? Icons.hourglass_top : Icons.login,
                          onPressed: widget.session.busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Giriş yapmadan BLE cihaz yapılandırmasına erişilemez.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );
}
