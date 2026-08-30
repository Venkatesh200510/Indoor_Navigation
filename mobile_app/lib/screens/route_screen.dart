import 'package:flutter/material.dart';
import '../models/route_result.dart';
import '../models/room.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class RouteScreen extends StatefulWidget {
  final RouteResult route;
  const RouteScreen({super.key, required this.route});
  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final TtsService _tts = TtsService();
  int _step = 0;
  bool _voiceOn = true;

  // Bumped every time the user interacts with voice (mute, tap a step,
  // prev/next). Any in-flight announcement loop checks this before
  // speaking its next line, so an old announcement can never talk over
  // something the user just triggered — this is what fixes the
  // "overlapping" voice assistant.
  int _speechGen = 0;

  List<PathwayImage> _images = [];
  bool _imagesLoading = true;

  @override
  void initState() {
    super.initState();
    _tts.init();
    // Fetch pathway images for all rooms on the route
    _loadImages();
    // Announce the route once the screen is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceRoute());
  }

  @override
  void dispose() {
    _speechGen++; // invalidate any pending loop before it can touch a disposed tts
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadImages() async {
    try {
      final imgs = await ApiService.getPathwayImages(widget.route.nodeIds);
      if (mounted) {
        setState(() {
          _images = imgs;
          _imagesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _imagesLoading = false);
    }
  }

  // Speaks the full route summary at the start. Bails out early if the
  // user interrupts (mutes, taps a step, presses prev/next) so it never
  // overlaps with whatever the user just asked to hear.
  Future<void> _announceRoute() async {
    if (!_voiceOn) return;
    final myGen = ++_speechGen;
    for (final line in widget.route.voiceScript) {
      if (myGen != _speechGen || !mounted) return;
      await _tts.speak(line);
      if (myGen != _speechGen || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  // Speaks just the current step direction. Also claims a new generation
  // so any older announcement loop still running stops instead of
  // continuing to speak over this.
  Future<void> _speakStep(int index) async {
    _speechGen++;
    if (!_voiceOn) return;
    final dirs = widget.route.directions;
    if (index < dirs.length) await _tts.speak(dirs[index]);
  }

  void _goToStep(int index) {
    setState(() => _step = index);
    _speakStep(index);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NAVIGATION ROUTE'),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                _voiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                key: ValueKey(_voiceOn),
                color: _voiceOn ? AppColors.mint : AppColors.textFaint,
              ),
            ),
            tooltip: _voiceOn ? 'Mute voice' : 'Unmute voice',
            onPressed: () {
              _speechGen++;
              setState(() => _voiceOn = !_voiceOn);
              if (_voiceOn) {
                _announceRoute();
              } else {
                _tts.stop();
              }
            },
          ),
        ],
      ),
      body: GradientBackdrop(
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 8),
            _buildFromTo(route.from, route.to, route.totalDistance),
            _buildProgress(route.directions.length),
            Expanded(child: _buildStepList(route)),
            _buildActions(route),
          ]),
        ),
      ),
    );
  }

  // Shows FROM → TO with floor numbers and distance
  Widget _buildFromTo(Room from, Room to, double dist) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      borderGradient: AppColors.brandGradient,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _floorChip(from.name, from.floor),
          Column(children: [
            const Icon(Icons.arrow_forward_rounded, color: AppColors.mint, size: 22),
            Text('${dist}m',
                style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ]),
          _floorChip(to.name, to.floor),
        ],
      ),
    );
  }

  Widget _floorChip(String name, int floor) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.violet.withValues(alpha: 0.6))),
              child: Text('Floor $floor',
                  style: const TextStyle(color: AppColors.violet, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  // Progress bar showing current step
  Widget _buildProgress(int total) {
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_step + 1} of $total',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const PulseDot(),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_step + 1) / total),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Stack(
                children: [
                  Container(height: 7, color: AppColors.surfaceAlt),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 7,
                      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Scrollable list of direction steps
  Widget _buildStepList(RouteResult route) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: route.directions.length,
      itemBuilder: (_, i) {
        final isActive = i == _step;
        final isDone = i < _step;
        // Find the corresponding pathway image for this step
        final nextRoom = i + 1 < route.path.length ? route.path[i + 1] : null;
        final img = _images
            .where((img) => img.nodeId == (nextRoom?.id ?? ''))
            .firstOrNull;

        return FadeSlideIn(
          index: i,
          child: Pressable(
            onTap: () => _goToStep(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.surfaceAlt
                    : (isDone ? AppColors.bgAlt : AppColors.surface),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isActive ? AppColors.mint : AppColors.outline,
                    width: isActive ? 1.6 : 1),
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.mint.withValues(alpha: 0.18), blurRadius: 16)]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step number circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isDone
                                ? const LinearGradient(colors: [AppColors.mintDim, AppColors.mint])
                                : (isActive ? AppColors.brandGradient : null),
                            color: (!isDone && !isActive) ? AppColors.surfaceAlt : null,
                          ),
                          child: Center(
                              child: isDone
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.black, size: 16)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: isActive ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (nextRoom != null)
                              Text(nextRoom.name,
                                  style: TextStyle(
                                      color: isActive ? AppColors.mint : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(route.directions[i],
                                style: TextStyle(
                                    color: isActive ? Colors.white : AppColors.textFaint,
                                    fontSize: 13)),
                          ],
                        )),
                        if (isActive)
                          Pressable(
                            onTap: () => _speakStep(i),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.volume_up_rounded,
                                  color: AppColors.mint, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Show the pathway image for this step if available
                  if (isActive && img != null && img.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                      child: Image.network(
                        img.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Bottom buttons: Previous / Next
  Widget _buildActions(RouteResult route) {
    final hasPrev = _step > 0;
    final hasNext = _step < route.directions.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(children: [
        // Previous button — only shown when not on first step
        if (hasPrev) ...[
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => _goToStep(_step - 1),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Prev'),
          )),
          const SizedBox(width: 10),
        ],
        // Next button — only shown when there are more steps; on the last
        // step this becomes a simple "reached" pill instead.
        Expanded(
          child: hasNext
              ? ElevatedButton.icon(
                  onPressed: () => _goToStep(_step + 1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next'),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('DESTINATION REACHED',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1)),
                  ),
                ),
        ),
      ]),
    );
  }
}
