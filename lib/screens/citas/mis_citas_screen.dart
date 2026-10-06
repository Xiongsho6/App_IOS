import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/cita.dart';
import '../../providers/citas_provider.dart';
import 'widgets/citas_shared_widgets.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CitasProvider>().cargar();
    });
  }

  String _subtitulo(int total) {
    if (total == 0) return 'Aún no tienes citas activas';
    if (total == 1) return '1 cita activa';
    return '$total citas activas';
  }

  @override
  Widget build(BuildContext context) {
    final citasProvider = context.watch<CitasProvider>();
    final total = citasProvider.citas.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CitasHeader(
        color: AppColors.green,
        titulo: 'Mis citas',
        subtitulo: _subtitulo(total),
      ),
      floatingActionButton: total > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.nuevaCita),
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () => context.read<CitasProvider>().cargar(),
          child: _buildBody(citasProvider),
        ),
      ),
    );
  }

  Widget _buildBody(CitasProvider citasProvider) {
    const fisica = AlwaysScrollableScrollPhysics();

    if (citasProvider.isLoading && citasProvider.citas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (citasProvider.status == CitasStatus.error &&
        citasProvider.citas.isEmpty) {
      return ListView(
        physics: fisica,
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.wifi_off_rounded,
              size: 44, color: AppColors.gray400),
          const SizedBox(height: 12),
          Text(
            citasProvider.errorMessage ?? 'No se pudieron cargar tus citas',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: () => context.read<CitasProvider>().cargar(),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (citasProvider.citas.isEmpty) {
      return ListView(
        physics: fisica,
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_outlined,
                  size: 34, color: AppColors.green),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes citas',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando agendes una, la verás aquí con su horario y estado de pago.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.gray600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.nuevaCita),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agendar una cita'),
          ),
        ],
      );
    }

    final citas = [...citasProvider.citas]
      ..sort((a, b) => a.fechaHoraCita.compareTo(b.fechaHoraCita));
    final hayError = citasProvider.status == CitasStatus.error;

    return ListView.separated(
      physics: fisica,
      // Espacio extra abajo para que el botón flotante no tape la última cita.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: citas.length + (hayError ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (hayError && i == 0) {
          return const AvisoCard.error(
            titulo: 'No se pudo actualizar',
            subtitulo:
                'Mostramos la última información disponible. Desliza hacia abajo para reintentar.',
          );
        }
        final idx = hayError ? i - 1 : i;
        return _CitaCard(cita: citas[idx]);
      },
    );
  }
}

class _CitaCard extends StatelessWidget {
  final CitaDetalle cita;
  const _CitaCard({required this.cita});

  @override
  Widget build(BuildContext context) {
    final colorTexto = colorParaEspecialidad(cita.especialidad.nombre);
    final colorFondo = colorFondoParaEspecialidad(cita.especialidad.nombre);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colorFondo,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: colorTexto, shape: BoxShape.circle),
                  child: Icon(
                    iconoParaEspecialidad(cita.especialidad.nombre),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cita.especialidad.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colorTexto,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatoCompletoCita(cita.fechaHoraCita),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.gray600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _EstadoBadge(estado: cita.estado),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _FilaInfo('Médico', cita.especialidad.medico),
                const Divider(height: 18),
                _FilaInfo('Consultorio', cita.horario.consultorio),
                const Divider(height: 18),
                Row(
                  children: [
                    const Text('Pago',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.gray600)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _PagoBadge(
                            pago: cita.pago, precio: cita.especialidad.precio),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final String label;
  final String valor;
  const _FilaInfo(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.gray600)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, colorFondo) = switch (estado) {
      'cancelada' => (AppColors.red, AppColors.redLight),
      'reprogramada' || 'pendiente' => (AppColors.amber, AppColors.amberLight),
      _ => (AppColors.green, AppColors.greenLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoCita(estado),
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PagoBadge extends StatelessWidget {
  final PagoCita? pago;
  final double precio;
  const _PagoBadge({required this.pago, required this.precio});

  @override
  Widget build(BuildContext context) {
    if (pago == null) {
      return const Text(
        'Sin pago registrado',
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gray600),
      );
    }
    if (pago!.confirmado) {
      return Text(
        '✓ Confirmado · S/ ${pago!.monto.toStringAsFixed(0)}',
        textAlign: TextAlign.end,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green),
      );
    }
    return Text(
      '⏳ Pendiente en caja · S/ ${precio.toStringAsFixed(0)}',
      textAlign: TextAlign.end,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.amber),
    );
  }
}
