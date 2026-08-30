import 'package:flutter/material.dart';
import '../models/route_result.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class PanoramaScreen extends StatefulWidget {
  final List<String>       nodeIds;  // list of room IDs on the route
  final List<PathwayImage> images;   // pre-fetched image data

  const PanoramaScreen({
    super.key,
    required this.nodeIds,
    required this.images,
  });

  @override State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  int _current = 0;

  // Build a list of images that actually have valid URLs
  List<PathwayImage> get _validImages =>
    widget.images.where((img) => img.imageUrl.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final imgs = _validImages;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          imgs.isEmpty ? '360° VIEW' : (imgs[_current].name.toUpperCase()),
          style: const TextStyle(letterSpacing: 2),
        ),
        backgroundColor: Colors.black,
      ),
      body: imgs.isEmpty
        ? _buildNoImages()
        : Column(children: [
            // 360° panorama viewer — drag left/right/up/down to look around
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  child: Image.network(
                    imgs[_current].imageUrl,
                    key: ValueKey(imgs[_current].imageUrl),
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(
                        color: AppColors.mint));
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.broken_image_rounded, color: Colors.white30, size: 64),
                        SizedBox(height: 12),
                        Text('Image not available',
                          style: TextStyle(color: Colors.white30)),
                      ])),
                  ),
                ),
              ),
            ),
            // Caption + navigation strip at the bottom
            _buildBottomStrip(imgs),
          ]),
    );
  }

  Widget _buildNoImages() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.panorama_fish_eye_rounded, color: Colors.white24, size: 72),
      SizedBox(height: 16),
      Text('No pathway images available yet.',
        style: TextStyle(color: Colors.white38, fontSize: 15)),
      SizedBox(height: 8),
      Text('Add images using the Admin Panel.',
        style: TextStyle(color: Colors.white24, fontSize: 13)),
    ]),
  );

  // Bottom strip with caption + prev/next thumbnails
  Widget _buildBottomStrip(List<PathwayImage> imgs) {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Caption
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(imgs[_current].caption,
            key: ValueKey(imgs[_current].caption),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        // Thumbnail strip
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imgs.length,
            itemBuilder: (_, i) {
              final isActive = i == _current;
              return Pressable(
                onTap: () => setState(() => _current = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 56,
                  transform: Matrix4.identity()..scale(isActive ? 1.06 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: isActive ? AppColors.brandGradient : null,
                    boxShadow: isActive
                        ? [BoxShadow(color: AppColors.mint.withValues(alpha: 0.4), blurRadius: 10)]
                        : null,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imgs[i].imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(
                        color: AppColors.surfaceAlt,
                        child: const Icon(Icons.image_rounded, color: Colors.white24, size: 24)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
