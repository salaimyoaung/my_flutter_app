import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen barcode scanner for IMEI numbers.
/// Returns the scanned IMEI string via Navigator.pop(), or null if cancelled.
///
/// Usage:
///   final imei = await Navigator.push<String>(
///     context,
///     MaterialPageRoute(builder: (_) => const ImeiScannerPage()),
///   );
class ImeiScannerPage extends StatefulWidget {
  const ImeiScannerPage({super.key});

  @override
  State<ImeiScannerPage> createState() => _ImeiScannerPageState();
}

class _ImeiScannerPageState extends State<ImeiScannerPage> {
  late final MobileScannerController _ctrl;
  bool _found = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.codabar,
      ],
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ✅ IMEI = exactly 15 digits
  bool _isImei(String value) => RegExp(r'^\d{15}$').hasMatch(value.trim());

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
    for (final barcode in capture.barcodes) {
      final raw = (barcode.rawValue ?? '').trim();
      if (_isImei(raw)) {
        _found = true;
        _ctrl.stop();
        if (mounted) Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  void _toggleTorch() {
    setState(() => _torchOn = !_torchOn);
    _ctrl.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'IMEI Scan',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
            ),
            tooltip: 'Flashlight',
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera feed ────────────────────────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // ── Dim overlay with cutout ────────────────────────────────────────
          _ScanOverlay(),

          // ── Instruction text ───────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: const [
                Text(
                  'ဖုန်း box ပေါ်က IMEI barcode ကို\nဘောင်ထဲ ထည့်ကိုင်ပါ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'IMEI = 15 digits — *#06# နှိပ်လည်း ရသည်',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan Overlay ──────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const frameW = 280.0;
    const frameH = 110.0;
    final left = (size.width - frameW) / 2;
    final top = (size.height - frameH) / 2 - 40;

    return Stack(
      children: [
        // Dark overlay
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: frameW,
                  height: frameH,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Green frame border
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: frameW,
            height: frameH,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 2.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        // Corner accents
        ..._corners(left: left, top: top, w: frameW, h: frameH),
      ],
    );
  }

  static List<Widget> _corners({
    required double left,
    required double top,
    required double w,
    required double h,
  }) {
    const size = 20.0;
    const thick = 4.0;
    const color = Colors.greenAccent;

    Widget corner(double l, double t, bool flipX, bool flipY) {
      return Positioned(
        left: l,
        top: t,
        child: Transform.scale(
          scaleX: flipX ? -1 : 1,
          scaleY: flipY ? -1 : 1,
          child: CustomPaint(
            size: const Size(size, size),
            painter: _CornerPainter(color: color, thickness: thick),
          ),
        ),
      );
    }

    return [
      corner(left - 1, top - 1, false, false),
      corner(left + w - size + 1, top - 1, true, false),
      corner(left - 1, top + h - size + 1, false, true),
      corner(left + w - size + 1, top + h - size + 1, true, true),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;

  const _CornerPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
