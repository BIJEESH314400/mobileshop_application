import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/service_job.dart';
import '../../../core/repositories/service_job_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import 'add_service_job_screen.dart';

/// Opened by tapping a job card -- full detail plus the two actions the
/// user asked for: move the job's status forward one stage, or edit its
/// info. Each status only ever offers the single, next logical move
/// (Pending -> In Progress -> Ready -> Picked Up/Completed) rather than
/// a free-pick list, so a job can't accidentally jump stages or go
/// backwards from here.
void showServiceJobDetailSheet(BuildContext context, ServiceJob job) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServiceJobDetailSheet(job: job),
  );
}

class _ServiceJobDetailSheet extends StatefulWidget {
  final ServiceJob job;
  const _ServiceJobDetailSheet({required this.job});

  @override
  State<_ServiceJobDetailSheet> createState() => _ServiceJobDetailSheetState();
}

class _ServiceJobDetailSheetState extends State<_ServiceJobDetailSheet> {
  bool _working = false;

  ServiceJobStatus? get _nextStatus {
    switch (widget.job.status) {
      case ServiceJobStatus.pending:
        return ServiceJobStatus.inProgress;
      case ServiceJobStatus.inProgress:
        return ServiceJobStatus.ready;
      case ServiceJobStatus.ready:
        return ServiceJobStatus.completed;
      case ServiceJobStatus.completed:
        return null;
    }
  }

  String get _nextStatusLabel {
    switch (_nextStatus) {
      case ServiceJobStatus.inProgress:
        return 'Start Repair';
      case ServiceJobStatus.ready:
        return 'Mark Ready';
      case ServiceJobStatus.completed:
        return 'Mark Picked Up';
      case ServiceJobStatus.pending:
      case null:
        return '';
    }
  }

  Future<void> _advanceStatus() async {
    final next = _nextStatus;
    if (next == null) return;

    // Picking the device up is the moment the price is actually
    // settled with the customer -- the amount on the job so far is
    // really just an estimate from whenever it was created/edited, so
    // this one transition (and only this one) asks to confirm or
    // change it before the job is marked Completed, instead of silently
    // keeping whatever number happened to be on there.
    if (next == ServiceJobStatus.completed) {
      final finalPrice = await _confirmPickupPrice();
      if (finalPrice == null || !mounted) return; // cancelled
      setState(() => _working = true);
      try {
        await ServiceJobRepository().completeJob(widget.job.id, finalPrice: finalPrice);
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e, st) {
        AppLogger.error('ServiceJobDetailSheet._advanceStatus (completeJob)', e, st);
        if (!mounted) return;
        setState(() => _working = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text("Couldn't update status -- check your connection and try again")));
      }
      return;
    }

    setState(() => _working = true);
    try {
      await ServiceJobRepository().updateStatus(widget.job.id, next);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      AppLogger.error('ServiceJobDetailSheet._advanceStatus', e, st);
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't update status -- check your connection and try again")));
    }
  }

  /// Small confirm-or-edit-the-price dialog shown only on the Ready ->
  /// Picked Up transition. Pre-filled with the job's current price.
  /// Returns the confirmed amount, or null if the person cancelled.
  Future<double?> _confirmPickupPrice() async {
    final p = AppPalette.of(context);
    final job = widget.job;
    final controller = TextEditingController(
      text: job.price == job.price.roundToDouble() ? job.price.toStringAsFixed(0) : job.price.toString(),
    );
    String? error;

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: p.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirm final price', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      "Before handing the device back, confirm or change the price.",
                      style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: error != null ? AppColors.danger : p.border),
                      ),
                      child: Row(
                        children: [
                          Text('₹', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textSecondary)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(fontSize: 15, color: p.textPrimary),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.border)),
                              child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final value = double.tryParse(controller.text.replaceAll(',', '').trim());
                              if (value == null || value < 0) {
                                setDialogState(() => error = 'Enter a valid price');
                                return;
                              }
                              Navigator.of(dialogContext).pop(value);
                            },
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                              child: const Text('Confirm Pickup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _edit() async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddServiceJobScreen(job: widget.job)));
  }

  Future<void> _call() async {
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: widget.job.customerPhone));
      if (!launched) throw Exception('launchUrl returned false for tel:${widget.job.customerPhone}');
    } catch (e, st) {
      AppLogger.error('ServiceJobDetailSheet._call', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open the dialer")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final job = widget.job;
    final hasPhone = job.customerPhone.isNotEmpty;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(color: p.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(job.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: _edit,
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, size: 15, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(job.deviceModel, style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
              const SizedBox(height: 18),
              _DetailRow(palette: p, label: 'Status', value: job.status.label),
              if (job.customerName.isNotEmpty) _DetailRow(palette: p, label: 'Customer', value: job.customerName),
              _DetailRow(palette: p, label: 'Price', value: '₹${job.price.toStringAsFixed(0)}'),
              if (job.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('NOTES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p.textSecondary, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(job.notes, style: TextStyle(fontSize: 13.5, color: p.textPrimary, height: 1.4)),
              ],
              const SizedBox(height: 20),
              if (hasPhone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _call,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_outlined, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text('Call ${job.customerName}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_nextStatus != null)
                GestureDetector(
                  onTap: _working ? null : _advanceStatus,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: _working
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text(_nextStatusLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                )
              else
                Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Job completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final String value;
  const _DetailRow({required this.palette, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: palette.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.textPrimary))),
        ],
      ),
    );
  }
}
