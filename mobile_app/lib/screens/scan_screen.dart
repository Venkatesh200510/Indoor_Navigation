import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../utils/transitions.dart';
import 'destination_screen.dart';
import 'manual_search_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  bool    _busy  = false;
  String? _error;
  late AnimationController _lineCtrl;
  late Animation<double>   _lineAnim;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _lineCtrl.dispose(); super.dispose(); }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() { _busy = true; _error = null; });

    try {
      final room = await ApiService.scanLocation(raw);
      if (!mounted) return;
      // Navigate to destination picker — pass the found room
      await pushFancy(context, DestinationScreen(currentRoom: room));
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Unexpected error: $e'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INDOOR NAVIGATOR'),
        actions: [
          IconButton(
            tooltip: 'Search rooms',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => pushFancy(context, const ManualSearchScreen()),
          ),
        ],
      ),
      body: GradientBackdrop(
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 4),
            _buildHeader(),
            Expanded(child: _buildCameraView()),
            _buildFooter(),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    child: Column(children: [
      ShaderMask(
        shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
        child: const Text('SCAN QR CODE',
          style: TextStyle(color: Colors.white, fontSize: 22,
            fontWeight: FontWeight.bold, letterSpacing: 4)),
      ),
      const SizedBox(height: 6),
      const Text('Point camera at the QR sticker on the door',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 4),
      const Text('or tap search to type current and destination',
        style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
    ]),
  );

  Widget _buildCameraView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppColors.brandGradient,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            // Live camera feed
            MobileScanner(onDetect: _busy ? null : _onDetect),
            // Dark overlay + glowing corner brackets
            CustomPaint(painter: _ScanOverlay(), child: const SizedBox.expand()),
            // Animated scan line
            if (!_busy) AnimatedBuilder(
              animation: _lineAnim,
              builder: (_, __) => Positioned(
                top: 80 + _lineAnim.value * 220,
                left: 50, right: 50,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, AppColors.mint, AppColors.violet, Colors.transparent]),
                    boxShadow: [BoxShadow(
                      color: AppColors.mint.withValues(alpha: 0.7),
                      blurRadius: 8)],
                  ),
                ),
              ),
            ),
            // Loading spinner while API call is in progress
            if (_busy) Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.mint),
                  SizedBox(height: 16),
                  Text('Identifying location...',
                    style: TextStyle(color: AppColors.mint, fontSize: 15)),
                ],
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() { _error = null; _busy = false; }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ]),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulseDot(),
          SizedBox(width: 8),
          Text('Ready to scan',
            style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
        ],
      ),
    );
  }
}

// Custom painter that draws the dark overlay + glowing corner brackets
class _ScanOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final l = s.width * 0.10, t = s.height * 0.08;
    final r = s.width * 0.90, b = s.height * 0.62;
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, s.width, t), dark);
    canvas.drawRect(Rect.fromLTRB(0, b, s.width, s.height), dark);
    canvas.drawRect(Rect.fromLTRB(0, t, l, b), dark);
    canvas.drawRect(Rect.fromLTRB(r, t, s.width, b), dark);
    final lp = Paint()
      ..shader = const LinearGradient(colors: [AppColors.mint, AppColors.violet])
          .createShader(Rect.fromLTRB(l, t, r, b))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const n = 28.0;
    canvas.drawLine(Offset(l,t+n),Offset(l,t),lp); canvas.drawLine(Offset(l,t),Offset(l+n,t),lp);
    canvas.drawLine(Offset(r-n,t),Offset(r,t),lp); canvas.drawLine(Offset(r,t),Offset(r,t+n),lp);
    canvas.drawLine(Offset(l,b-n),Offset(l,b),lp); canvas.drawLine(Offset(l,b),Offset(l+n,b),lp);
    canvas.drawLine(Offset(r-n,b),Offset(r,b),lp); canvas.drawLine(Offset(r,b),Offset(r,b-n),lp);
  }
  @override bool shouldRepaint(_) => false;
}
