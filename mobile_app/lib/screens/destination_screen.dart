import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/route_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../utils/transitions.dart';
import 'route_screen.dart';

class DestinationScreen extends StatefulWidget {
  final Room currentRoom;
  const DestinationScreen({super.key, required this.currentRoom});
  @override State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  List<Room> _rooms   = [];
  Room?      _selected;
  bool       _loading = true;
  String?    _error;

  // Image of the room the user just scanned into (shown in the "you are
  // here" card).
  PathwayImage? _currentImage;

  // Cache of destination-room images, keyed by room id, fetched lazily the
  // first time a room is tapped so we don't refetch on every tap.
  final Map<String, PathwayImage?> _destImageCache = {};

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadCurrentImage();
  }

  Future<void> _loadRooms() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await ApiService.getRooms();
      setState(() {
        // Remove current room from destinations — can't navigate to where you already are
        _rooms   = all.where((r) => r.id != widget.currentRoom.id).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // Fetches the pathway image for the room the user is currently standing in.
  Future<void> _loadCurrentImage() async {
    try {
      final imgs = await ApiService.getPathwayImages([widget.currentRoom.id]);
      if (!mounted) return;
      setState(() => _currentImage = imgs.firstOrNull);
    } catch (_) {
      // No image available — the "you are here" card just shows text only.
    }
  }

  // Selects a destination room and lazily fetches its preview image.
  Future<void> _selectRoom(Room room) async {
    setState(() => _selected = room);
    if (_destImageCache.containsKey(room.id)) return;
    try {
      final imgs = await ApiService.getPathwayImages([room.id]);
      if (!mounted) return;
      setState(() => _destImageCache[room.id] = imgs.firstOrNull);
    } catch (_) {
      if (mounted) setState(() => _destImageCache[room.id] = null);
    }
  }

  Future<void> _navigate() async {
    if (_selected == null) return;

    // Show a loading spinner in a dialog while fetching the route
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.mint)),
    );

    try {
      final route = await ApiService.findRoute(
        widget.currentRoom.id, _selected!.id);
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      pushFancy(context, RouteScreen(route: route));
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.danger.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SELECT DESTINATION')),
      body: GradientBackdrop(
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 8),
            _buildCurrentLocationCard(),
            Expanded(child: _buildBody()),
            _buildDestinationPreview(),
            _buildNavigateButton(),
          ]),
        ),
      ),
    );
  }

  // Shows a card at the top with 'You are here: [room name]' plus the
  // pathway image for that room, if one has been uploaded in the admin panel.
  Widget _buildCurrentLocationCard() {
    final room = widget.currentRoom;
    final hasImage = _currentImage != null && _currentImage!.imageUrl.isNotEmpty;
    return GlassPanel(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      borderGradient: AppColors.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: const Icon(Icons.my_location_rounded, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('YOU ARE HERE',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
                Text(room.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
                Text('Floor ${room.floor}  ·  ${room.type}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
          ]),
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentImage!.imageUrl,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const SizedBox(
                      height: 130,
                      child: Center(child: CircularProgressIndicator(color: AppColors.mint, strokeWidth: 2)),
                    ),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
      child: CircularProgressIndicator(color: AppColors.mint));
    }
    if (_error != null) return _buildError();
    if (_rooms.isEmpty) {
      return const Center(
      child: Text('No rooms available.',
        style: TextStyle(color: AppColors.textSecondary)));
    }
    return _buildRoomList();
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 52),
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger, fontSize: 14)),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _loadRooms,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ]),
    ));
  }

  // Rooms are grouped by floor for easier navigation
  Widget _buildRoomList() {
    final byFloor = <int, List<Room>>{};
    for (final r in _rooms) {
      (byFloor[r.floor] ??= []).add(r);
    }
    final floors = byFloor.keys.toList()..sort();

    int flatIndex = 0;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final floor in floors) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 6, height: 16,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Text('FLOOR $floor',
                style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11, letterSpacing: 3,
                  fontWeight: FontWeight.bold)),
            ]),
          ),
          ...byFloor[floor]!.map((room) => _buildRoomTile(room, flatIndex++)),
        ],
      ],
    );
  }

  Widget _buildRoomTile(Room room, int index) {
    final isSelected = _selected?.id == room.id;
    return FadeSlideIn(
      index: index,
      child: Pressable(
        onTap: () => _selectRoom(room),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceAlt : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.mint : AppColors.outline,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.mint.withValues(alpha: 0.16), blurRadius: 14)]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.mint.withValues(alpha: 0.18) : AppColors.surfaceAlt,
              ),
              child: Icon(_roomIcon(room.type),
                color: isSelected ? AppColors.mint : AppColors.textFaint,
                size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: TextStyle(
                  color: isSelected ? AppColors.mint : Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
                Text(room.type,
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ],
            )),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 22, key: ValueKey('sel'))
                  : const SizedBox(width: 22, height: 22, key: ValueKey('unsel')),
            ),
          ]),
        ),
      ),
    );
  }

  // Icon for each room type
  IconData _roomIcon(String type) => switch (type) {
    'lab'       => Icons.computer_rounded,
    'classroom' => Icons.school_rounded,
    'corridor'  => Icons.linear_scale_rounded,
    'stairs'    => Icons.stairs_rounded,
    'facility'  => Icons.account_balance_rounded,
    'office'    => Icons.business_center_rounded,
    _           => Icons.room_rounded,
  };

  // Small preview strip shown once a destination is picked — the room's
  // pathway image (if the admin panel has one) plus its name/caption.
  Widget _buildDestinationPreview() {
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();

    final img = _destImageCache[selected.id];
    final hasImage = img != null && img.imageUrl.isNotEmpty;

    return FadeSlideIn(
      child: GlassPanel(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasImage
                ? Image.network(
                    img.imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _previewPlaceholder(selected.type),
                  )
                : _previewPlaceholder(selected.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DESTINATION PREVIEW',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                Text(selected.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (hasImage && img.caption.isNotEmpty)
                  Text(img.caption,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _previewPlaceholder(String type) => Container(
        width: 64,
        height: 64,
        color: AppColors.surfaceAlt,
        child: Icon(_roomIcon(type), color: AppColors.textFaint, size: 26),
      );

  Widget _buildNavigateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _selected != null ? _navigate : null,
          icon: const Icon(Icons.navigation_rounded),
          label: Text(_selected != null
            ? 'NAVIGATE TO ${_selected!.name.toUpperCase()}'
            : 'SELECT A DESTINATION'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
            disabledBackgroundColor: AppColors.surfaceAlt,
            disabledForegroundColor: AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}
