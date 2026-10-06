import 'package:go_router/go_router.dart';

import '../../data/models/especialidad_horario.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/citas/nueva_cita_screen.dart';
import '../../screens/citas/cancelar_cita_screen.dart';
import '../../screens/citas/reprogramar_cita_screen.dart';
import '../../screens/citas/mis_citas_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/registro';
  static const forgotPassword = '/recuperar-password';
  static const dashboard = '/dashboard';
  static const nuevaCita = '/citas/nueva';
  static const cancelarCita = '/citas/cancelar';
  static const reprogramarCita = '/citas/reprogramar';
  static const misCitas = '/citas';

  static final router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: nuevaCita,
        builder: (context, state) => NuevaCitaScreen(
          especialidadInicial: state.extra is EspecialidadApi
              ? state.extra as EspecialidadApi
              : null,
        ),
      ),
      GoRoute(
        path: cancelarCita,
        builder: (context, state) => const CancelarCitaScreen(),
      ),
      GoRoute(
        path: reprogramarCita,
        builder: (context, state) => const ReprogramarCitaScreen(),
      ),
      GoRoute(
        path: misCitas,
        builder: (context, state) => const MisCitasScreen(),
      ),
    ],
  );
}
