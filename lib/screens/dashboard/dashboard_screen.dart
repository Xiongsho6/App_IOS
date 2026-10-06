import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../data/models/cita.dart';
import '../../data/models/especialidad_horario.dart';
import '../../data/repositories/citas_local_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/citas_provider.dart';

class ProximaCita {
  final int dia;
  final String mes;
  final String especialidad;
  final String horaYLugar;
  final String estado;

  const ProximaCita({
    required this.dia,
    required this.mes,
    required this.especialidad,
    required this.horaYLugar,
    required this.estado,
  });

  factory ProximaCita.desde(CitaDetalle c) {
    final f = c.fechaHoraCita;
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return ProximaCita(
      dia: f.day,
      mes: meses[f.month - 1],
      especialidad: c.especialidad.nombre,
      horaYLugar: '${formatoHoraCita(f)} · ${c.horario.consultorio}',
      estado: etiquetaEstadoCita(c.estado),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = CitasLocalRepository();
  List<EspecialidadApi> _especialidades = [];

  @override
  void initState() {
    super.initState();
    _cargarEspecialidades();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CitasProvider>().cargar();
    });
  }

  Future<void> _cargarEspecialidades() async {
    try {
      final lista = await _repo.listarEspecialidades();
      if (!mounted) return;
      setState(() => _especialidades = lista);
    } catch (_) {
      // Si falla, la sección de especialidades simplemente no se muestra.
    }
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora >= 5 && hora < 12) return 'Buenos días';
    if (hora >= 12 && hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _iniciales(String nombre, String apellido) {
    final n = nombre.isNotEmpty ? nombre[0] : '';
    final a = apellido.isNotEmpty ? apellido[0] : '';
    return (n + a).toUpperCase();
  }

  Future<void> _abrirPerfil(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final paciente = auth.currentPaciente;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mi perfil', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (paciente != null) ...[
                _PerfilRow(
                    label: 'Nombre',
                    value: '${paciente.nombre} ${paciente.apellido}'),
                _PerfilRow(label: 'DNI', value: paciente.documento),
                _PerfilRow(label: 'Correo', value: paciente.correo),
                _PerfilRow(label: 'Teléfono', value: paciente.telefono),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Cerrar sesión'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await auth.logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final paciente = auth.currentPaciente;
    final nombre = paciente != null ? paciente.nombre : 'Paciente';
    final iniciales =
        paciente != null ? _iniciales(paciente.nombre, paciente.apellido) : '?';

    final citasProvider = context.watch<CitasProvider>();
    final citaMasProxima = citasProvider.proximaCita;
    final proximaCita =
        citaMasProxima != null ? ProximaCita.desde(citaMasProxima) : null;
    final tienePagoPendiente = citasProvider.tienePagoPendiente;
    final citasConPagoPendiente =
        citasProvider.citas.where((c) => c.pago?.pendienteEnCaja == true);
    final citaConPagoPendiente =
        citasConPagoPendiente.isNotEmpty ? citasConPagoPendiente.first : null;
    final cargandoCitas =
        citasProvider.isLoading && citasProvider.citas.isEmpty;
    final sinCitas = !cargandoCitas && proximaCita == null;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _saludo().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _abrirPerfil(context),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        iniciales,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.green,
                onRefresh: () async {
                  await Future.wait([
                    context.read<CitasProvider>().cargar(),
                    _cargarEspecialidades(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cargandoCitas) ...[
                        const _Titulo('Próxima cita'),
                        const SizedBox(height: 8),
                        const _CargandoCitaCard(),
                      ] else if (sinCitas)
                        _SinCitasCard(
                          onAgendar: () => context.push(AppRoutes.nuevaCita),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _Titulo('Próxima cita'),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.misCitas),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Ver todas →',
                                  style: TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.misCitas),
                          child: _CitaCard(cita: proximaCita!),
                        ),
                        if (tienePagoPendiente) ...[
                          const SizedBox(height: 12),
                          _AvisoPagoPendiente(cita: citaConPagoPendiente),
                        ],
                        const SizedBox(height: 24),
                        const _Titulo('¿Qué deseas hacer?'),
                        const SizedBox(height: 8),
                        _AccionPrincipal(
                          onTap: () => context.push(AppRoutes.nuevaCita),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _AccionSecundaria(
                                icon: Icons.close,
                                iconBg: AppColors.redLight,
                                iconColor: AppColors.red,
                                label: 'Cancelar\ncita',
                                onTap: () =>
                                    context.push(AppRoutes.cancelarCita),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AccionSecundaria(
                                icon: Icons.event_repeat,
                                iconBg: AppColors.amberLight,
                                iconColor: AppColors.amber,
                                label: 'Reprogramar\ncita',
                                onTap: () =>
                                    context.push(AppRoutes.reprogramarCita),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_especialidades.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _Titulo('Especialidades'),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _especialidades.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final e = _especialidades[i];
                              return _EspecialidadCard(
                                especialidad: e,
                                onTap: () => context.push(
                                  AppRoutes.nuevaCita,
                                  extra: e,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _BottomNav(
              onMisCitas: () => context.push(AppRoutes.misCitas),
              onPerfil: () => _abrirPerfil(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.gray600,
      ),
    );
  }
}

class _PerfilRow extends StatelessWidget {
  final String label;
  final String value;
  const _PerfilRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: AppColors.gray600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CargandoCitaCard extends StatelessWidget {
  const _CargandoCitaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _SinCitasCard extends StatelessWidget {
  final VoidCallback onAgendar;
  const _SinCitasCard({required this.onAgendar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available,
                color: AppColors.green, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no tienes citas',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agenda tu primera consulta en pocos pasos: elige la especialidad, el horario y cómo pagar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.gray600),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAgendar,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agendar mi primera cita'),
          ),
        ],
      ),
    );
  }
}

class _CitaCard extends StatelessWidget {
  final ProximaCita cita;
  const _CitaCard({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cita.dia}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(cita.mes,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cita.especialidad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(cita.horaYLugar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.gray600)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(cita.estado,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray400),
        ],
      ),
    );
  }
}

class _AccionPrincipal extends StatelessWidget {
  final VoidCallback onTap;
  const _AccionPrincipal({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: AppColors.green.withValues(alpha: 0.25), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available,
                    color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nueva cita',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.greenDark)),
                    SizedBox(height: 1),
                    Text('Elige especialidad y horario',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.gray600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccionSecundaria extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _AccionSecundaria({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EspecialidadCard extends StatelessWidget {
  final EspecialidadApi especialidad;
  final VoidCallback onTap;

  const _EspecialidadCard({required this.especialidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorParaEspecialidad(especialidad.nombre);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconoParaEspecialidad(especialidad.nombre),
                      color: Colors.white, size: 18),
                ),
                const Spacer(),
                Text(especialidad.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('S/ ${especialidad.precio.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.gray600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoPagoPendiente extends StatelessWidget {
  final CitaDetalle? cita;
  const _AvisoPagoPendiente({this.cita});

  @override
  Widget build(BuildContext context) {
    final subtitulo = cita != null
        ? 'Cita del ${formatoDiaMesCita(cita!.fechaHoraCita)} · ${cita!.especialidad.nombre}'
        : 'Revisa el detalle en Mis citas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pago pendiente en caja',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amberDark)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.amber)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onMisCitas;
  final VoidCallback onPerfil;
  const _BottomNav({required this.onMisCitas, required this.onPerfil});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.gray100)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                active: true,
                onTap: () {},
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.event_note_outlined,
                label: 'Mis citas',
                active: false,
                onTap: onMisCitas,
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                active: false,
                onTap: onPerfil,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.gray400;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
