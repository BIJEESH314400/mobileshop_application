import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/service_job.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../bloc/service_bloc.dart';
import '../bloc/service_event.dart';
import '../bloc/service_state.dart';
import 'add_service_job_screen.dart';
import 'service_job_detail_sheet.dart';

/// Service Jobs -- live Firestore data as of 2026-10-06 (previously 4
/// static reference jobs, see the design-canvas section of the status
/// doc for how the visual layout was first pulled from the design
/// canvas). Filter-pill layout/colors unchanged: "All * N" + Pending /
/// In Progress / Ready (no separate Completed pill -- a completed job
/// only ever shows under "All", same as before).
class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServiceBloc()..add(const ServiceSubscriptionRequested()),
      child: const _ServiceView(),
    );
  }
}

class _ServiceView extends StatefulWidget {
  const _ServiceView();

  @override
  State<_ServiceView> createState() => _ServiceViewState();
}

class _ServiceViewState extends State<_ServiceView> {
  String _tab = 'all'; // 'all' | 'pending' | 'inProgress' | 'ready'

  static const Map<String, ServiceJobStatus?> _tabStatus = {
    'all': null,
    'pending': ServiceJobStatus.pending,
    'inProgress': ServiceJobStatus.inProgress,
    'ready': ServiceJobStatus.ready,
  };

  Future<void> _addJob(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddServiceJobScreen()));
    // No explicit refresh needed -- ServiceBloc's live stream picks up
    // the new document on its own, same as every other live list here.
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wantStatus = _tabStatus[_tab];

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Service Jobs',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _addJob(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BlocBuilder<ServiceBloc, ServiceState>(
                    builder: (context, state) {
                      return SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 20),
                          children: [
                            _FilterPill(
                              palette: p,
                              label: 'All · ${state.jobs.length}',
                              selected: _tab == 'all',
                              onTap: () => setState(() => _tab = 'all'),
                            ),
                            const SizedBox(width: 6),
                            _FilterPill(
                              palette: p,
                              label: 'Pending',
                              selected: _tab == 'pending',
                              onTap: () => setState(() => _tab = 'pending'),
                            ),
                            const SizedBox(width: 6),
                            _FilterPill(
                              palette: p,
                              label: 'In Progress',
                              selected: _tab == 'inProgress',
                              onTap: () => setState(() => _tab = 'inProgress'),
                            ),
                            const SizedBox(width: 6),
                            _FilterPill(
                              palette: p,
                              label: 'Ready',
                              selected: _tab == 'ready',
                              onTap: () => setState(() => _tab = 'ready'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ServiceBloc, ServiceState>(
                builder: (context, state) {
                  if (state.isLoading && state.jobs.isEmpty) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  if (state.errorMessage != null && state.jobs.isEmpty) {
                    return Center(child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)));
                  }
                  final jobs = wantStatus == null ? state.jobs : state.jobs.where((j) => j.status == wantStatus).toList();
                  if (jobs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.jobs.isEmpty ? 'No repair jobs yet.\nTap "+" above to add the first one.' : 'No jobs in this status',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _JobCard(
                      palette: p,
                      job: jobs[i],
                      onTap: () => showServiceJobDetailSheet(context, jobs[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.service),
    );
  }
}

/// "today"/"yesterday"/"N days ago" -- same relative-date idea used for
/// Dashboard's Recent Sales row and the Sales History date grouping,
/// kept local here since the exact wording ("Dropped off .../Started
/// .../Ready since .../Picked up ...") is specific to a job's status.
String _relativeLabel(DateTime? date) {
  if (date == null) return 'just now';
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'yesterday';
  return '$diff days ago';
}

String _statusAgeLabel(ServiceJob job) {
  switch (job.status) {
    case ServiceJobStatus.pending:
      return 'Dropped off ${_relativeLabel(job.createdAt)}';
    case ServiceJobStatus.inProgress:
      return 'Started ${_relativeLabel(job.statusChangedAt)}';
    case ServiceJobStatus.ready:
      return 'Ready since ${_relativeLabel(job.statusChangedAt)}';
    case ServiceJobStatus.completed:
      return 'Picked up ${_relativeLabel(job.statusChangedAt)}';
  }
}

class _FilterPill extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        // Scroll the tapped pill fully into view -- previously a pill
        // sitting at the scrolled-away edge (e.g. the last category)
        // stayed partially cut off even after being selected, so the
        // selection itself gave no feedback unless the user also
        // scrolled manually. Scheduled for the next frame so this runs
        // after onTap()'s setState has rebuilt the row.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent : palette.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color badgeBg;
  final Color badgeColor;
  const _StatusStyle(this.badgeBg, this.badgeColor);
}

class _JobCard extends StatelessWidget {
  final AppPalette palette;
  final ServiceJob job;
  final VoidCallback onTap;

  const _JobCard({required this.palette, required this.job, required this.onTap});

  String get _statusLabel => job.status.label;

  _StatusStyle get _style {
    switch (job.status) {
      case ServiceJobStatus.inProgress:
        return _StatusStyle(AppColors.warningBg, AppColors.warningText);
      case ServiceJobStatus.ready:
        return _StatusStyle(AppColors.successBg, AppColors.success);
      case ServiceJobStatus.completed:
        return _StatusStyle(AppColors.accent.withOpacity(0.10), AppColors.accent);
      case ServiceJobStatus.pending:
        // Canvas keeps Pending neutral gray rather than a status color --
        // follows the theme (light/dark) instead of a fixed brand hue.
        return _StatusStyle(palette.divider, palette.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final subtitle = job.customerName.isEmpty ? job.deviceModel : '${job.deviceModel} · ${job.customerName}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: s.badgeBg, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.build_rounded, size: 18, color: s.badgeColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: s.badgeBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.badgeColor),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.divider))),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: palette.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _statusAgeLabel(job),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '₹${job.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
