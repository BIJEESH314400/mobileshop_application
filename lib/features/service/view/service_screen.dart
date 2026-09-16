import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// Service Jobs — matches the design canvas exactly: "All · N" + Pending /
/// In Progress / Ready filter pills (no separate "Completed" pill —
/// completed jobs only ever show under "All"), and job cards with a wrench
/// icon, status badge, ETA row and price. Static reference data; filter
/// selection is local widget state, no ServiceBloc yet.
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

enum _JobStatus { pending, inProgress, ready, completed }

class _ServiceScreenState extends State<ServiceScreen> {
  String _tab = 'all'; // 'all' | 'pending' | 'inProgress' | 'ready'

  static const List<_JobData> _jobs = [
    _JobData(
      title: 'Screen replacement',
      subtitle: 'OnePlus Nord · Priya Menon',
      eta: 'Due today',
      price: '₹2,400',
      status: _JobStatus.inProgress,
    ),
    _JobData(
      title: 'Battery replacement',
      subtitle: 'iPhone 12 · Aman Gupta',
      eta: 'Ready since yesterday',
      price: '₹1,800',
      status: _JobStatus.ready,
    ),
    _JobData(
      title: 'Water damage check',
      subtitle: 'Redmi Note 12 · Kavya S.',
      eta: 'Dropped off today',
      price: 'Est. ₹500',
      status: _JobStatus.pending,
    ),
    _JobData(
      title: 'Software update & backup',
      subtitle: 'iPhone 11 · Rahul Verma',
      eta: 'Picked up 2 days ago',
      price: '₹300',
      status: _JobStatus.completed,
    ),
  ];

  static const Map<String, _JobStatus?> _tabStatus = {
    'all': null,
    'pending': _JobStatus.pending,
    'inProgress': _JobStatus.inProgress,
    'ready': _JobStatus.ready,
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wantStatus = _tabStatus[_tab];
    final jobs = wantStatus == null ? _jobs : _jobs.where((j) => j.status == wantStatus).toList();

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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _comingSoon(context, 'New Repair'),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterPill(
                          palette: p,
                          label: 'All · ${_jobs.length}',
                          selected: _tab == 'all',
                          onTap: () => setState(() => _tab = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          palette: p,
                          label: 'Pending',
                          selected: _tab == 'pending',
                          onTap: () => setState(() => _tab = 'pending'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          palette: p,
                          label: 'In Progress',
                          selected: _tab == 'inProgress',
                          onTap: () => setState(() => _tab = 'inProgress'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          palette: p,
                          label: 'Ready',
                          selected: _tab == 'ready',
                          onTap: () => setState(() => _tab = 'ready'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: jobs.isEmpty
                  ? Center(
                      child: Text(
                        'No jobs in this status',
                        style: TextStyle(color: p.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _JobCard(palette: p, job: jobs[i]),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.service),
    );
  }
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
}

class _JobData {
  final String title;
  final String subtitle;
  final String eta;
  final String price;
  final _JobStatus status;

  const _JobData({
    required this.title,
    required this.subtitle,
    required this.eta,
    required this.price,
    required this.status,
  });
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
  final _JobData job;

  const _JobCard({required this.palette, required this.job});

  String get _statusLabel {
    switch (job.status) {
      case _JobStatus.pending:
        return 'Pending';
      case _JobStatus.inProgress:
        return 'In Progress';
      case _JobStatus.ready:
        return 'Ready';
      case _JobStatus.completed:
        return 'Completed';
    }
  }

  _StatusStyle get _style {
    switch (job.status) {
      case _JobStatus.inProgress:
        return _StatusStyle(AppColors.warningBg, AppColors.warningText);
      case _JobStatus.ready:
        return _StatusStyle(AppColors.successBg, AppColors.success);
      case _JobStatus.completed:
        return _StatusStyle(AppColors.accent.withOpacity(0.10), AppColors.accent);
      case _JobStatus.pending:
        // Canvas keeps Pending neutral gray rather than a status color —
        // follows the theme (light/dark) instead of a fixed brand hue.
        return _StatusStyle(palette.divider, palette.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
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
                decoration: BoxDecoration(
                  color: s.badgeBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.build_rounded, size: 18, color: s.badgeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.subtitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: s.badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.badgeColor),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: palette.textSecondary),
                const SizedBox(width: 6),
                Text(
                  job.eta,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                ),
                const Spacer(),
                Text(
                  job.price,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
