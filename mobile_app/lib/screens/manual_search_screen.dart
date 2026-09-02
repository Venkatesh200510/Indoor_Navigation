import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Which field the suggestion list is filling. Stays set after keyboard
  /// dismiss so a tap on a recommendation still lands on the right field.
  bool _pickingFrom = true;

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() {
      if (_fromFocus.hasFocus) setState(() => _pickingFrom = true);
    });
    _toFocus.addListener(() {
      if (_toFocus.hasFocus) setState(() => _pickingFrom = false);
    });
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

  String get _activeQuery =>
      (_pickingFrom ? _fromCtrl.text : _toCtrl.text).trim();

  Room? get _exclude => _pickingFrom ? _to : _from;

  List<Room> _matches() {
    final q = _activeQuery.toLowerCase();
    return _rooms.where((r) {
      if (_exclude != null && r.id == _exclude!.id) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q) ||
          r.type.toLowerCase().contains(q) ||
          'floor ${r.floor}'.contains(q);
    }).toList();
  }

  /// Exact name or id match so typing "LH101" counts without tapping a row.
  Room? _resolveTyped(String raw, Room? exclude) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;
    final hits = _rooms.where((r) {
      if (exclude != null && r.id == exclude.id) return false;
      return r.name.toLowerCase() == q || r.id.toLowerCase() == q;
    }).toList();
    return hits.length == 1 ? hits.first : null;
  }

  void _syncFromText(String v) {
    setState(() {
      _pickingFrom = true;
      _from = _resolveTyped(v, _to);
    });
  }

  void _syncToText(String v) {
    setState(() {
      _pickingFrom = false;
      _to = _resolveTyped(v, _from);
    });
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
    HapticFeedback.selectionClick();
    setState(() {
      _from = room;
      _fromCtrl.value = TextEditingValue(
        text: room.name,
        selection: TextSelection.collapsed(offset: room.name.length),
      );
      if (_to?.id == room.id) {
        _to = null;
        _toCtrl.clear();
      }
      _pickingFrom = false;
    });
    _fromFocus.unfocus();
    _toFocus.requestFocus();
  }

  void _pickTo(Room room) {
    HapticFeedback.selectionClick();
    setState(() {
      _to = room;
      _toCtrl.value = TextEditingValue(
        text: room.name,
        selection: TextSelection.collapsed(offset: room.name.length),
      );
    });
    _toFocus.unfocus();
  }

  Future<void> _findRoute() async {
    final from = _from ?? _resolveTyped(_fromCtrl.text, _to);
    final to = _to ?? _resolveTyped(_toCtrl.text, _from);
    if (from == null || to == null) return;
    if (from.id == to.id) {
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
      final route = await ApiService.findRoute(from.id, to.id);
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

  bool get _ready {
    final from = _from ?? _resolveTyped(_fromCtrl.text, _to);
    final to = _to ?? _resolveTyped(_toCtrl.text, _from);
    return from != null && to != null && from.id != to.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          textInputAction: TextInputAction.next,
          onChanged: _syncFromText,
          onSubmitted: (_) {
            _syncFromText(_fromCtrl.text);
            _toFocus.requestFocus();
          },
          onClear: () => setState(() {
            _from = null;
            _fromCtrl.clear();
            _pickingFrom = true;
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
          textInputAction: TextInputAction.done,
          onChanged: _syncToText,
          onSubmitted: (_) {
            _syncToText(_toCtrl.text);
            _toFocus.unfocus();
          },
          onClear: () => setState(() {
            _to = null;
            _toCtrl.clear();
            _pickingFrom = false;
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
    required TextInputAction textInputAction,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
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
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
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
    final matches = _matches();
    final heading = _pickingFrom ? 'PICK CURRENT LOCATION' : 'PICK DESTINATION';

    if (matches.isEmpty) {
      return const Center(
        child: Text('No rooms match that search.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(heading,
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: matches.length,
            itemBuilder: (_, i) {
              final room = matches[i];
              final selected = _pickingFrom
                  ? _from?.id == room.id
                  : _to?.id == room.id;
              return _SuggestionTile(
                room: room,
                selected: selected,
                icon: _roomIcon(room.type),
                onSelect: () => _pickingFrom ? _pickFrom(room) : _pickTo(room),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFindButton() {
    final ready = _ready;
    final destName = (_to ?? _resolveTyped(_toCtrl.text, _from))?.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: ready ? _findRoute : null,
          icon: const Icon(Icons.navigation_rounded),
          label: Text(ready
              ? 'NAVIGATE TO ${destName!.toUpperCase()}'
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

/// Selects on pointer-down so the keyboard unfocus cannot eat the tap.
class _SuggestionTile extends StatelessWidget {
  final Room room;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelect;

  const _SuggestionTile({
    required this.room,
    required this.selected,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                child: Icon(icon,
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
      ),
    );
  }
}
