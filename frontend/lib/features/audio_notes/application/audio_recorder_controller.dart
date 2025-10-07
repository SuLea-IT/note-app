import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum RecorderStatus { idle, recording, paused, saving, error }

class AudioRecorderState {
  const AudioRecorderState({
    this.status = RecorderStatus.idle,
    this.duration = Duration.zero,
    this.filePath,
    this.error,
  });

  final RecorderStatus status;
  final Duration duration;
  final String? filePath;
  final String? error;

  AudioRecorderState copyWith({
    RecorderStatus? status,
    Duration? duration,
    String? filePath,
    bool clearFilePath = false,
    String? error,
    bool clearError = false,
  }) {
    return AudioRecorderState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AudioRecorderController extends ChangeNotifier {
  AudioRecorderController({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  AudioRecorderState _state = const AudioRecorderState();
  AudioRecorderState get state => _state;

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _timer;

  double _currentLevel = 0;
  double get currentLevel => _currentLevel;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    if (_state.status == RecorderStatus.recording) {
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        _setState((state) => state.copyWith(status: RecorderStatus.error, error: '麦克风权限被拒绝'));
        return;
      }
      final directory = await getApplicationSupportDirectory();
      final fileName = 'audio-${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${directory.path}/$fileName';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _listenAmplitude();
      _startTimer();
      _setState(
        (state) => state.copyWith(
          status: RecorderStatus.recording,
          duration: Duration.zero,
          filePath: path,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AudioRecorderController start error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: RecorderStatus.error,
          error: '开始录音失败',
        ),
      );
    }
  }

  Future<void> pause() async {
    if (_state.status != RecorderStatus.recording) {
      return;
    }
    await _recorder.pause();
    _setState((state) => state.copyWith(status: RecorderStatus.paused));
  }

  Future<void> resume() async {
    if (_state.status != RecorderStatus.paused) {
      return;
    }
    await _recorder.resume();
    _setState((state) => state.copyWith(status: RecorderStatus.recording));
  }

  Future<String?> stop({bool save = true}) async {
    if (_state.status != RecorderStatus.recording && _state.status != RecorderStatus.paused) {
      return null;
    }
    _setState((state) => state.copyWith(status: RecorderStatus.saving));
    try {
      final path = await _recorder.stop();
      _disposeStreams();
      if (!save) {
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        _setState(
          (state) => const AudioRecorderState(status: RecorderStatus.idle),
        );
        return null;
      }
      _setState(
        (state) => state.copyWith(
          status: RecorderStatus.idle,
          duration: state.duration,
          filePath: path,
        ),
      );
      return path;
    } catch (error, stackTrace) {
      debugPrint('AudioRecorderController stop error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: RecorderStatus.error,
          error: '保存录音失败',
        ),
      );
      return null;
    }
  }

  void reset() {
    _disposeStreams();
    _setState((_) => const AudioRecorderState());
  }

  void _listenAmplitude() {
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 160)).listen(
      (amplitude) {
        _currentLevel = amplitude.current;
        notifyListeners();
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _setState(
          (state) => state.copyWith(duration: Duration(seconds: timer.tick)),
        );
      });
  }

  void _disposeStreams() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _timer?.cancel();
    _timer = null;
    _currentLevel = 0;
  }

  @override
  void dispose() {
    _disposeStreams();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _setState(AudioRecorderState Function(AudioRecorderState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}