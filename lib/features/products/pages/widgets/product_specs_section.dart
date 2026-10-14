import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/product_model.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ProductSpecsSection  — 3-column verification table (dark mode)
// ─────────────────────────────────────────────────────────────────────────────

class ProductSpecsSection extends StatelessWidget {
  final Product product;
  /// Set false to render C.E.I.R. / Device Verification separately
  final bool showVerification;
  const ProductSpecsSection({
    super.key,
    required this.product,
    this.showVerification = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conditionLower = product.condition.toLowerCase();
    final isUsed = conditionLower.contains("open box") ||
        conditionLower.contains("like new") ||
        conditionLower.contains("used");
    final isIphone =
        product.deviceType == "iphone" || product.deviceType == "ipad";
    final acc = product.accessories;
    final isRefurbished = product.condition.toLowerCase().contains('refurb');
    final verified  = product.specsVerified;   // null | 'verified' | 'mismatch'
    final ceirDone  = product.ceirCheckedAt != null;

    // ── Build spec rows list ──────────────────────────────────────────────────
    final specs = <_SD>[];
    specs.add(_SD(
      "Condition",
      product.condition.trim().isNotEmpty ? product.condition : "—",
      verifiable: false,
      isHighlight: isUsed, // ✅ Use isUsed here to highlight if it's a used device
    ));
    specs.add(_SD("Storage",
        product.storage != null ? "${product.storage}GB" : "—"));
    specs.add(_SD("Color",
        product.color.trim().isNotEmpty ? product.color : "—"));
    if (isIphone && product.modelNumber?.isNotEmpty == true) {
      specs.add(_SD("Model No.", product.modelNumber!, verifiable: false));
    }
    if (isIphone && product.simType.isNotEmpty) {
      specs.add(_SD("SIM Type", _fmtSimType(product.simType), verifiable: false));
    }
    if (!isIphone) {
      specs.add(_SD("RAM",
        product.ram != null ? "${product.ram}GB" : "—"));
    }
    if (isIphone && product.batteryPercent != null) {
      specs.add(_SD("Battery", "${product.batteryPercent}%",
          verifiable: false));
    }
    if (isIphone && product.cycleCount != null) {
      specs.add(_SD("Cycle Count", "${product.cycleCount}",
          verifiable: false));
    }
    specs.add(_SD("Warranty", _fmtWarranty(product.warrantyDays),
        verifiable: false));
    if (product.version?.isNotEmpty == true) {
      specs.add(_SD("Version", product.version!));
    }
    if (product.rom?.isNotEmpty == true) {
      specs.add(_SD("ROM", product.rom!));
    }
    if (isIphone && product.icloudStatus.isNotEmpty) {
      specs.add(_SD("iCloud",
          product.icloudStatus == 'clean' ? 'Clean' : 'Locked',
          verifiable: false));
    }
    if (isIphone && product.carrierLock.isNotEmpty) {
      specs.add(_SD("Carrier",
          product.carrierLock == 'unlocked' ? 'Unlocked' : 'Locked',
          verifiable: false));
    }
    if (product.imeiMasked.trim().isNotEmpty) {
      specs.add(_SD("IMEI", product.imeiMasked));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GSMArenaButton(productName: product.name),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Column headers ────────────────────────────────────────────────
              const _TableHeader(),
              const _HDivider(),

              // ── Spec rows ─────────────────────────────────────────────────────
              ...specs.asMap().entries.expand((e) => [
                _SpecRow(data: e.value, alt: e.key.isOdd),
                if (e.key < specs.length - 1)
                  Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant),
              ]),

              // ── C.E.I.R. + Device Verification (hidden when showVerification=false)
              if (showVerification) ...[
                const _HDivider(),
                _SectionLabel(
                  "C.E.I.R. Verification",
                  timestamp: ceirDone
                      ? _timeAgo(product.ceirCheckedAt!.toDate())
                      : null,
                ),
                _CeirRow("IMEI Status", ceirDone ? product.ceirImeiStatus : null,
                    good: 'correct', alt: false),
                const _HDivider(),
                _CeirRow("Tax Payment", ceirDone ? product.ceirTaxStatus : null,
                    good: 'paid', alt: true),
                const _HDivider(),
                _CeirRow("Blocking", ceirDone ? product.ceirBlockingStatus : null,
                    good: 'allowed', alt: false),
                const _HDivider(),
                _SectionLabel(
                  "Device Verification",
                  timestamp: product.specsVerifiedAt != null
                      ? _timeAgo(product.specsVerifiedAt!.toDate())
                      : null,
                ),
                if (isRefurbished)
                  _DevVerRow(verified: 'not_required', note: '')
                else
                  _DevVerRow(verified: verified, note: product.specsMismatchNote),
              ],

              // ── Accessories ───────────────────────────────────────────────────
              if (acc.isNotEmpty) ...[
                const _HDivider(),
                const _SectionLabel("Accessories Included"),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (acc['box'] == true) _AccChip("Box"),
                      if (acc['charger'] == true) _AccChip("Charger"),
                      if (acc['cable'] == true) _AccChip("Cable"),
                      if (acc['earphones'] == true) _AccChip("Earphones"),
                      if (acc['receipt'] == true) _AccChip("Receipt"),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ProductVerificationSection  — C.E.I.R. + Device Verification rows only
// ─────────────────────────────────────────────────────────────────────────────

class ProductVerificationSection extends StatelessWidget {
  final Product product;
  const ProductVerificationSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final verified     = product.specsVerified;
    final ceirDone     = product.ceirCheckedAt != null;
    final isRefurbished = product.condition.toLowerCase().contains('refurb');
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _SectionLabel(
            "C.E.I.R. Verification",
            timestamp: ceirDone
                ? _timeAgo(product.ceirCheckedAt!.toDate())
                : null,
          ),
          _CeirRow("IMEI Status",
              ceirDone ? product.ceirImeiStatus : null,
              good: 'correct', alt: false),
          _CeirRow("Tax Payment",
              ceirDone ? product.ceirTaxStatus : null,
              good: 'paid', alt: true),
          _CeirRow("Blocking",
              ceirDone ? product.ceirBlockingStatus : null,
              good: 'allowed', alt: false),

          const _HDivider(),
          _SectionLabel(
            "Device Verification",
            timestamp: product.specsVerifiedAt != null
                ? _timeAgo(product.specsVerifiedAt!.toDate())
                : null,
          ),
          if (isRefurbished)
            _DevVerRow(verified: 'not_required', note: '')
          else
            _DevVerRow(verified: verified, note: product.specsMismatchNote),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SD {
  final String label;
  final String value;
  /// false = admin cannot verify this field (Warranty, Condition)
  final bool   verifiable;
  final bool   isHighlight;
  const _SD(this.label, this.value, {this.verifiable = true, this.isHighlight = false});
}

String _fmtWarranty(int? days) {
  if (days == null) return "—";
  if (days == 0)    return "No warranty";
  switch (days) {
    case 3:   return "3 days";
    case 7:   return "7 days";
    case 14:  return "14 days";
    case 30:  return "30 days";
    case 90:  return "3 months";
    case 180: return "6 months";
    case 365: return "1 year";
    case 730: return "2 years";
    default:  return "$days days";
  }
}

String _fmtSimType(String? type) {
  if (type == null || type.isEmpty) return "—";
  switch (type) {
    case 'single':
      return 'Single SIM (Nano)';
    case 'dual_esim':
      return 'Dual SIM (Nano + eSIM)';
    case 'dual_nano':
      return 'Dual SIM (Nano + Nano)';
    case 'esim_only':
      return 'eSIM Only';
    default:
      return type;
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes} မိနစ်က';
  if (diff.inHours   < 24) return '${diff.inHours} နာရီက';
  if (diff.inDays    < 7)  return '${diff.inDays} ရက်က';
  return '${dt.day}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
}

// ─── Table Header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final style = tt.labelSmall?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("အချက်အလက်", style: style)),
          Expanded(
            flex: 5,
            child: Text(
              "ရောင်းသူ ပြချက်",
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GSMArena Button ─────────────────────────────────────────────────────────

class _GSMArenaButton extends StatelessWidget {
  final String productName;
  const _GSMArenaButton({required this.productName});

  Future<void> _launchGSMArena(BuildContext context) async {
    final query = Uri.encodeComponent('$productName gsmarena specs');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browser မဖွင့်နိုင်ပါ')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _launchGSMArena(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Text(
              "GSMArena တွင် အသေးစိတ်ကြည့်ရန်",
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

// ─── Spec Row (seller spec + admin verification status) ───────────────────────

class _SpecRow extends StatelessWidget {
  final _SD     data;
  final bool    alt;

  const _SpecRow({
    required this.data,
    required this.alt,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final labelStyle = tt.bodySmall?.copyWith(color: scheme.onSurface, fontSize: 11);
    final valStyle   = tt.bodySmall?.copyWith(
      color: data.isHighlight ? Colors.orange.shade700 : scheme.onSurface,
      fontWeight: data.isHighlight ? FontWeight.w800 : FontWeight.w600,
      fontSize: 12,
    );

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(data.label, style: labelStyle)),
          Expanded(flex: 5, child: Text(data.value, textAlign: TextAlign.end, style: valStyle)),
        ],
      ),
    );
  }
}

// ─── Admin Cell (used by both _SpecRow and _CeirRow) ─────────────────────────

/// For spec rows: shows overall specsVerified result.
/// For CEIR rows: shows per-field CEIR result (pass [ceirValue] + [ceirGood]).
class _AdminCell extends StatelessWidget {
  /// When non-null, this cell shows a CEIR-specific result instead
  final String? ceirValue;
  final String? ceirGood;

  const _AdminCell({
    this.ceirValue,
    this.ceirGood,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // ── CEIR mode ────────────────────────────────────────────────────────────
    if (ceirValue != null) {
      final displayMap = {
        'correct':   'Correct',   'incorrect': 'Incorrect',
        'paid':      'Paid',      'unpaid':    'Unpaid',
        'allowed':   'Allowed',   'blocked':   'Blocked',
      };
      final isGood   = ceirValue == ceirGood;
      final display  = displayMap[ceirValue] ?? ceirValue!;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(
                color: isGood ? Colors.green.shade300 : Colors.red.shade300,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isGood ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isGood ? Colors.green : Colors.red.shade400,
          ),
        ],
      );
    }

    // null = pending (default fallback)
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "စစ်ဆဲ",
          style: tt.bodySmall?.copyWith(color: Colors.amber.shade400, fontSize: 11),
        ),
        const SizedBox(width: 4),
        Icon(Icons.hourglass_top_rounded, size: 13, color: Colors.amber.shade400),
      ],
    );
  }
}

// ─── CEIR Row ─────────────────────────────────────────────────────────────────

class _CeirRow extends StatelessWidget {
  final String  label;
  final String? value; // null = not checked yet
  final String  good;
  final bool    alt;

  const _CeirRow(this.label, this.value, {required this.good, required this.alt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: tt.bodySmall?.copyWith(color: scheme.onSurface, fontSize: 11)),
          ),
          Expanded(
            flex: 4,
            child: Text("—",
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: value == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("စစ်ဆဲ",
                            style: tt.bodySmall?.copyWith(
                                color: Colors.amber.shade400, fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(Icons.hourglass_top_rounded,
                            size: 13, color: Colors.amber.shade400),
                      ],
                    )
                  : _AdminCell(ceirValue: value, ceirGood: good),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Device Verification Summary Row ─────────────────────────────────────────

class _DevVerRow extends StatelessWidget {
  final String? verified;
  final String  note;
  const _DevVerRow({required this.verified, required this.note});

  @override
  Widget build(BuildContext context) {
    if (verified == 'not_required') {
      return _tile(context,
        icon: Icons.info_outline,
        iconColor: Colors.grey,
        bg: Colors.grey.withValues(alpha: 0.06),
        border: Colors.grey.withValues(alpha: 0.2),
        text: "China Refurbished — Device Verification မလိုအပ်ပါ။",
        textColor: Colors.grey,
      );
    }

    if (verified == 'verified') {
      return _tile(context,
        icon: Icons.verified_rounded,
        iconColor: Colors.green,
        bg: Colors.green.withValues(alpha: 0.08),
        border: Colors.green.withValues(alpha: 0.3),
        text: "ဝယ်သူဘက်က Order တင်ပြီးချိန်တွင် ရောင်းသူ ဖော်ပြထားသည့် Specifications များကို imei.org တွင် ထပ်မံ စစ်ဆေးပေးပါသည်။ ကိုက်ညီမှုရှိပြီး လော့ခ်ကင်းစင်မှသာ (ဥပမာ -Sim Lock, Network Lock, iCloud Lock, Mi Lock, Samsung KG/MDM Lock မရှိမှသာ) Approve ပေးပါမည်။ admin approve ရရှိပြီးချိန်တွင် Device verification result ကို Buyer orderတွင် မြင်တွေ့ရမည် ဖြစ်ပါသည်။ Deliveryမှ ပစ္စည်းလာပို့ချိိန်တွင်လည်း ရောင်းသူ၏ ဖော်ပြပါ အချက်အလက်များ ကိုက်ညီမှု ရှိမရှိ ငွေမချေခင် ဖောက်စစ်ပိုင်ခွင့် ရှိသည်။ ကိုက်ညီမှု မရှိပါက ကိုက်ညီမှု မရှိသော အချက်အလက်များကို သက်သေအနေဖြင့် ဓာတ်ပုံရိုက်ထားပြီး ငွေချေစရာမလိုဘဲ return ပြန်ပို့နိုင်သည်။ ဝယ်သူ၏ return ပြန်ပို့သည့် အကြောင်းပြချက် ခိုင်လုံပါက adminထံမှ depositငွေ ပြန်လည် ရရှိမည် ဖြစ်ပါသည်",
        textColor: Colors.green.shade300,
      );
    }

    if (verified == 'mismatch') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tile(context,
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red.shade400,
            bg: Colors.red.withValues(alpha: 0.08),
            border: Colors.red.withValues(alpha: 0.3),
            text: "Seller ဖော်ပြချက်နှင့် Device မကိုက်ညီပါ။",
            textColor: Colors.red.shade300,
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                "မှတ်ချက်: $note",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade200,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      );
    }

    // null = pending
    return _tile(context,
      icon: Icons.hourglass_top_rounded,
      iconColor: Colors.amber.shade400,
      bg: Colors.amber.withValues(alpha: 0.06),
      border: Colors.amber.withValues(alpha: 0.25),
      text: "Device မစစ်ဆေးရသေးပါ။ Admin မကြာမီ စစ်ဆေးပေးပါမည်။",
      textColor: Colors.amber.shade300,
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color    iconColor,
    required Color    bg,
    required Color    border,
    required String   text,
    required Color    textColor,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String  label;
  final String? timestamp;
  const _SectionLabel(this.label, {this.timestamp});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: tt.labelSmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              )),
          if (timestamp != null) ...[
            const Spacer(),
            Text(timestamp!,
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Horizontal Divider ───────────────────────────────────────────────────────

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.outlineVariant);
}

// ─── Accessory Chip ───────────────────────────────────────────────────────────

class _AccChip extends StatelessWidget {
  final String label;
  const _AccChip(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: scheme.onSurface, fontSize: 11)),
        ],
      ),
    );
  }
}
