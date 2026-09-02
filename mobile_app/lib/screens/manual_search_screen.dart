import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../utils/transitions.dart';
import 'route_screen.dart';

/// Manual From / To search so the user can pick rooms by name instead of
/// scanning a QR code.
class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key});
  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  List<Room> _rooms = [];
  bool _loading = true;
  String? _error;

  Room? _from;
  Room? _to;

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  String _fromQuery = '';
  String _toQuery = '';
  bool _fromFocused = false;
  bool _toFocused = false;

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() => setState(() => _fromFocused = _fromFocus.hasFocus));
    _toFocus.addListener(() => setState(() => _toFocused = _toFocus.hasFocus));
    _loadRooms();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await ApiService.getRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<Room> _matches(String query, Room? exclude) {
    final q = query.trim().toLowerCase();
    return _rooms.where((r) {
      if (exclude != null && r.id == exclude.id) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.type.toLowerCase().contains(q) ||
          'floor ${r.floor}'.contains(q);
    }).toList();
  }

  IconData _roomIcon(String type) => switch (type) {
        'lab' => Icons.computer_rounded,
        'classroom' => Icons.school_rounded,
        'corridor' => Icons.linear_scale_rounded,
        'stairs' => Icons.stairs_rounded,
        'facility' => Icons.account_balance_rounded,
        'office' => Icons.business_center_rounded,
        _ => Icons.room_rounded,
      };

  void _pickFrom(Room room) {
    setState(() {
      _from = room;
      _fromQuery = room.name;
      _fromCtrl.text = room.name;
      _fromCtrl.selection = TextSelection.collapsed(offset: room.name.length);
      if (_to?.id == room.id) {
        _to = null;
        _toQuery = '';
        _toCtrl.clear();
      }
    });
    _fromFocus.unfocus();
  }

  void _pickTo(Room room) {
    setState(() {
      _to = room;
      _toQuery = room.name;
      _toCtrl.text = room.name;
      _toCtrl.selection = TextSelection.collapsed(offset: room.name.length);
    });
    _toFocus.unfocus();
  }

  Future<void> _findRoute() async {
    if (_from == null || _to == null) return;
    if (_from!.id == _to!.id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Current location and destination must be different.'),
        backgroundColor: AppColors.danger.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.mint),
      ),
    );

    try {
      final route = await ApiService.findRoute(_from!.id, _to!.id);
      if (!mounted) return;
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('SEARCH ROUTE')),
      body: GradientBackdrop(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.mint))
              : _error != null
                  ? _buildError()
                  : Column(children: [
                      _buildSearchFields(),
                      Expanded(child: _buildSuggestions()),
                      _buildFindButton(),
                    ]),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 52),
          const SizedBox(height: 14),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 14)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _loadRooms,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  Widget _buildSearchFields() {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderGradient: AppColors.brandGradient,
      child: Column(children: [
        _locationField(
          label: 'CURRENT LOCATION',
          hint: 'Type where you are now',
          icon: Icons.my_location_rounded,
          controller: _fromCtrl,
          focusNode: _fromFocus,
          selected: _from,
          onChanged: (v) => setState(() {
            _fromQuery = v;
            if (_from != null && v != _from!.name) _from = null;
          }),
          onClear: () => setState(() {
            _from = null;
            _fromQuery = '';
            _fromCtrl.clear();
            _fromFocus.requestFocus();
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            const SizedBox(width: 18),
            Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Spacer(),
            Pressable(
              onTap: () {
                final from = _from;
                final to = _to;
                final fromText = _fromCtrl.text;
                final toText = _toCtrl.text;
                setState(() {
                  _from = to;
                  _to = from;
                  _fromQuery = toText;
                  _toQuery = fromText;
                  _fromCtrl.text = toText;
                  _toCtrl.text = fromText;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceAlt,
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Icon(Icons.swap_vert_rounded, color: AppColors.mint, size: 18),
              ),
            ),
          ]),
        ),
        _locationField(
          label: 'DESTINATION',
          hint: 'Type where you want to go',
          icon: Icons.flag_rounded,
          controller: _toCtrl,
          focusNode: _toFocus,
          selected: _to,
          onChanged: (v) => setState(() {
            _toQuery = v;
            if (_to != null && v != _to!.name) _to = null;
          }),
          onClear: () => setState(() {
            _to = null;
            _toQuery = '';
            _toCtrl.clear();
            _toFocus.requestFocus();
          }),
        ),
      ]),
    );
  }

  Widget _locationField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Room? selected,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    final filled = selected != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        cursorColor: AppColors.mint,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w400, fontSize: 14),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          prefixIcon: Icon(icon, color: filled ? AppColors.mint : AppColors.textFaint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textFaint, size: 18),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: filled ? AppColors.mint : AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.mint, width: 1.6),
          ),
        ),
      ),
      if (filled)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('Floor ${selected.floor}  ·  ${selected.type}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
    ]);
  }

  Widget _buildSuggestions() {
    final showFrom = _fromFocused;
    final showTo = _toFocused && !showFrom;
    final query = showFrom ? _fromQuery : (showTo ? _toQuery : '');
    final exclude = showFrom ? _to : (showTo ? _from : null);
    final pickingFrom = showFrom;

    if (!showFrom && !showTo) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, color: AppColors.textFaint.withValues(alpha: 0.7), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Tap a field and type a room name,\nor pick from the matching list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
            ),
          ]),
        ),
      );
    }

    final matches = _matches(query, exclude);
    if (matches.isEmpty) {
      return const Center(
        child: Text('No rooms match that search.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final room = matches[i];
        final selected = pickingFrom ? _from?.id == room.id : _to?.id == room.id;
        return FadeSlideIn(
          index: i.clamp(0, 8),
          child: Pressable(
            onTap: () => pickingFrom ? _pickFrom(room) : _pickTo(room),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceAlt : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.mint : AppColors.outline,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.mint.withValues(alpha: 0.18)
                        : AppColors.surfaceAlt,
                  ),
                  child: Icon(_roomIcon(room.type),
                      color: selected ? AppColors.mint : AppColors.textFaint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(room.name,
                        style: TextStyle(
                          color: selected ? AppColors.mint : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        )),
                    Text('Floor ${room.floor}  ·  ${room.type}',
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFindButton() {
    final ready = _from != null && _to != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: ready ? _findRoute : null,
          icon: const Icon(Icons.navigation_rounded),
          label: Text(ready
              ? 'NAVIGATE TO ${_to!.name.toUpperCase()}'
              : 'PICK CURRENT AND DESTINATION'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
            disabledBackgroundColor: AppColors.surfaceAlt,
            disabledForegroundColor: AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}
