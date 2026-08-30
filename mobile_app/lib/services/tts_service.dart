import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48); // slightly slow for clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // IMPORTANT: without this, speak() returns as soon as the request is
    // *queued* rather than when the audio actually finishes playing. That
    // is what caused the route announcement and the step-by-step callouts
    // to race each other and talk over one another. Awaiting real
    // completion makes speak() behave as "one line at a time".
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// Speaks [text], cancelling anything currently playing first.
  /// Resolves only once this line has actually finished speaking.
  Future<void> speak(String text) async {
    if (!_ready) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
