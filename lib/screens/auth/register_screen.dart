import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_field.dart';

enum _Step { form, otp }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  _Step _step = _Step.form;
  bool _loading = false;
  String? _error;

  static final _correoRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _hasMinLength => _passCtrl.text.length >= 8;
  bool get _hasUpper => _passCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passCtrl.text.contains(RegExp(r'[0-9]'));

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _documentoCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _showOtpDialog(String codigo) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Código de verificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como esta app no tiene servidor ni SMS real, aquí está tu '
              'código de verificación (modo desarrollo):',
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

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final codigo = await context.read<AuthProvider>().registrar(
            nombre: _nombreCtrl.text.trim(),
            apellido: _apellidoCtrl.text.trim(),
            documento: _documentoCtrl.text.trim(),
            correo: _correoCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
            password: _passCtrl.text,
          );
      if (!mounted) return;
      await _showOtpDialog(codigo);
      if (!mounted) return;
      setState(() {
        _step = _Step.otp;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo crear la cuenta. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _submitOtp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context
          .read<AuthProvider>()
          .verificarCodigoSms(_documentoCtrl.text.trim(), _otpCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cuenta verificada. Ya puedes iniciar sesión.')),
      );
      context.go(AppRoutes.login);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'No se pudo verificar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviarOtp() async {
    try {
      final codigo = await context
          .read<AuthProvider>()
          .reenviarOtp(_documentoCtrl.text.trim());
      await _showOtpDialog(codigo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reenviar el código')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _Step.form ? 'Crear cuenta' : 'Verificar código'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: _step == _Step.form ? _buildForm() : _buildOtpStep(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus datos',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Los usaremos para agendar y confirmar tus citas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 13)),
            const SizedBox(height: 20),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _apellidoCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _documentoCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(labelText: 'DNI'),
              validator: (v) => (v == null || v.trim().length != 8)
                  ? 'El DNI debe tener 8 dígitos'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _correoCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration:
                  const InputDecoration(labelText: 'Correo electrónico'),
              validator: (v) => (v == null || !_correoRegExp.hasMatch(v.trim()))
                  ? 'Correo inválido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) => (v == null || v.trim().length != 9)
                  ? 'Ingresa un celular de 9 dígitos'
                  : null,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _passCtrl,
              labelText: 'Contraseña',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (!_hasMinLength || !_hasUpper || !_hasNumber) {
                  return 'Mínimo 8 caracteres, 1 mayúscula y 1 número';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _Check('Mínimo 8 caracteres', _hasMinLength),
            _Check('Al menos una letra mayúscula', _hasUpper),
            _Check('Al menos un número', _hasNumber),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirmCtrl,
              labelText: 'Confirmar contraseña',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) {
                if (!_loading) _submitForm();
              },
              validator: (v) =>
                  v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submitForm,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => context.go(AppRoutes.login),
                child: const Text('Ya tengo cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 14),
        ],
        Text('Ingresa el código de verificación',
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text('Se generó un código local para el DNI ${_documentoCtrl.text}.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
        const SizedBox(height: 24),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (!_loading && _otpCtrl.text.length == 6) _submitOtp();
          },
          decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _loading ? null : _reenviarOtp,
            child: const Text('Ver / reenviar código'),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading || _otpCtrl.text.length != 6 ? null : _submitOtp,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verificar y continuar'),
        ),
      ],
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
