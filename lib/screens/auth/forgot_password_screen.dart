import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_field.dart';

enum _Step { dni, otp, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.dni;
  final _dniCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _dniCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _showOtpDialog(String codigo) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Código de recuperación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sin servidor no hay SMS real — aquí está tu código '
              '(modo desarrollo):',
            ),
            const SizedBox(height: 14),
            Center(
              child: SelectableText(
                codigo,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Válido por 10 minutos.',
                style: TextStyle(fontSize: 12, color: AppColors.gray600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Ejecuta una acción con el estado de carga y el manejo de errores
  /// en un solo lugar.
  Future<void> _ejecutar(
      Future<void> Function() accion, String mensajeFallback) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await accion();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = mensajeFallback);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitDni() => _ejecutar(() async {
        final codigo = await context
            .read<AuthProvider>()
            .solicitarRecuperacion(_dniCtrl.text.trim());
        if (!mounted) return;
        await _showOtpDialog(codigo);
        if (!mounted) return;
        setState(() => _step = _Step.otp);
      }, 'No se pudo solicitar el código. Intenta de nuevo.');

  Future<void> _reenviarOtp() async {
    try {
      final codigo =
          await context.read<AuthProvider>().reenviarOtp(_dniCtrl.text.trim());
      await _showOtpDialog(codigo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reenviar el código')));
    }
  }

  Future<void> _submitOtp() => _ejecutar(() async {
        await context.read<AuthProvider>().validarCodigoRecuperacion(
            _dniCtrl.text.trim(), _otpCtrl.text.trim());
        if (!mounted) return;
        setState(() => _step = _Step.newPassword);
      }, 'No se pudo verificar el código. Intenta de nuevo.');

  Future<void> _submitNewPassword() => _ejecutar(() async {
        await context.read<AuthProvider>().restablecerPassword(
              _dniCtrl.text.trim(),
              _otpCtrl.text.trim(),
              _passCtrl.text,
            );
        if (!mounted) return;
        setState(() => _step = _Step.done);
      }, 'No se pudo cambiar la contraseña. Intenta de nuevo.');

  void _atras() {
    if (_step == _Step.dni) {
      context.pop();
      return;
    }
    setState(() {
      _error = null;
      if (_step == _Step.otp) _otpCtrl.clear();
      if (_step == _Step.newPassword) {
        _passCtrl.clear();
        _confirmCtrl.clear();
      }
      _step = _Step.values[_step.index - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminado = _step == _Step.done;

    return PopScope(
      // El botón "atrás" del sistema retrocede un paso en vez de salir.
      canPop: _step == _Step.dni || terminado,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recuperar acceso'),
          automaticallyImplyLeading: false,
          leading: terminado
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver',
                  onPressed: _atras,
                ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!terminado) ...[
                  _ProgressBar(current: _step.index + 1),
                  const SizedBox(height: 20),
                ],
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 14),
                ],
                switch (_step) {
                  _Step.dni => _DniStep(
                      controller: _dniCtrl,
                      loading: _loading,
                      onSubmit: _submitDni,
                    ),
                  _Step.otp => _OtpStep(
                      controller: _otpCtrl,
                      loading: _loading,
                      onSubmit: _submitOtp,
                      onResend: _reenviarOtp,
                    ),
                  _Step.newPassword => _NewPasswordStep(
                      passCtrl: _passCtrl,
                      confirmCtrl: _confirmCtrl,
                      loading: _loading,
                      onSubmit: _submitNewPassword,
                    ),
                  _Step.done => _DoneStep(dni: _dniCtrl.text),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.redDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.redDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  const _ProgressBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final step = i + 1;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: step <= current ? AppColors.green : AppColors.gray100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('Paso $current de 3',
            style: const TextStyle(fontSize: 12, color: AppColors.gray600)),
      ],
    );
  }
}

class _DniStep extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  const _DniStep({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingresa tu DNI registrado',
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text('Se generará un código de verificación local para ese DNI.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          onSubmitted: (_) {
            if (!loading && controller.text.length == 8) onSubmit();
          },
          decoration: const InputDecoration(
            labelText: 'DNI',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => ElevatedButton(
            onPressed: loading || value.text.length != 8 ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enviar código'),
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  const _OtpStep({
    required this.controller,
    required this.loading,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingresa el código de recuperación',
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text('Es el código de 6 dígitos que se mostró en pantalla.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) {
            if (!loading && controller.text.length == 6) onSubmit();
          },
          decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: loading ? null : onResend,
            child: const Text('¿No lo viste? Ver / reenviar código'),
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => ElevatedButton(
            onPressed: loading || value.text.length != 6 ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Verificar código'),
          ),
        ),
      ],
    );
  }
}

class _NewPasswordStep extends StatelessWidget {
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool loading;
  final VoidCallback onSubmit;
  const _NewPasswordStep({
    required this.passCtrl,
    required this.confirmCtrl,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([passCtrl, confirmCtrl]),
      builder: (context, _) {
        final pass = passCtrl.text;
        final confirm = confirmCtrl.text;
        final hasMinLength = pass.length >= 8;
        final hasUpper = pass.contains(RegExp(r'[A-Z]'));
        final hasNumber = pass.contains(RegExp(r'[0-9]'));
        final hasSymbol = pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
        final coinciden = confirm.isNotEmpty && pass == confirm;
        final noCoinciden = confirm.isNotEmpty && pass != confirm;
        final valido = hasMinLength && hasUpper && hasNumber && coinciden;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elige una contraseña segura',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 22)),
            const SizedBox(height: 20),
            PasswordField(
              controller: passCtrl,
              labelText: 'Nueva contraseña',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 10),
            _Check('Mínimo 8 caracteres', hasMinLength),
            _Check('Al menos una letra mayúscula', hasUpper),
            _Check('Al menos un número', hasNumber),
            _Check('Un símbolo (!@#\$) — opcional', hasSymbol),
            const SizedBox(height: 14),
            PasswordField(
              controller: confirmCtrl,
              labelText: 'Confirmar contraseña',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) {
                if (!loading && valido) onSubmit();
              },
            ),
            if (noCoinciden) ...[
              const SizedBox(height: 6),
              const Text('Las contraseñas no coinciden',
                  style: TextStyle(fontSize: 12, color: AppColors.red)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading || !valido ? null : onSubmit,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar contraseña'),
            ),
          ],
        );
      },
    );
  }
}

class _Check extends StatelessWidget {
  final String label;
  final bool ok;
  const _Check(this.label, this.ok);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? AppColors.green : AppColors.gray400,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: ok ? AppColors.gray900 : AppColors.gray600)),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final String dni;
  const _DoneStep({required this.dni});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green100, width: 2.5),
            ),
            child:
                const Icon(Icons.lock_open, color: AppColors.green, size: 32),
          ),
          const SizedBox(height: 18),
          Text('¡Contraseña actualizada!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            'Tu cuenta ha sido desbloqueada.\nYa puedes ingresar con tu nueva contraseña.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Usuario',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.gray600)),
                      Text('${dni.isEmpty ? "-" : dni} (DNI)',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Acceso',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.gray600)),
                      Text('Desbloqueado',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Ir al login →'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Si no fuiste tú, llama al hospital inmediatamente',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
