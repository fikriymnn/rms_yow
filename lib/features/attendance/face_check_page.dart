import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

Uint8List _prepareJpeg(Uint8List raw) {
  var im = img.decodeJpg(raw);
  if (im == null) throw StateError('Foto tidak terbaca');
  im = img.bakeOrientation(im);
  if (math.max(im.width, im.height) > 480) {
    im = im.width >= im.height
        ? img.copyResize(im, width: 480)
        : img.copyResize(im, height: 480);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

class FaceCheckPage extends StatefulWidget {
  const FaceCheckPage({super.key});
  @override
  State<FaceCheckPage> createState() => _FaceCheckPageState();
}

class _FaceCheckPageState extends State<FaceCheckPage> {
  CameraController? _cam;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.3,
    ),
  );

  String _message = 'Menyiapkan kamera...';
  String? _fatal;
  bool _busy = false;
  bool _capturing = false;
  bool _done = false;
  int _openFrames = 0;
  bool _armed = false;
  bool _sawClosed = false;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  @override
  void dispose() {
    _done = true;
    final cam = _cam;
    () async {
      try {
        if (cam != null && cam.value.isStreamingImages)
          await cam.stopImageStream();
      } catch (_) {}
      await cam?.dispose();
      await _detector.close();
    }();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _fail(
          'Izin kamera ditolak. Izinkan kamera di pengaturan aplikasi untuk absen.',
        );
        return;
      }
      final cams = await availableCameras();
      CameraDescription? front;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.front) front = c;
      }
      front ??= cams.isNotEmpty ? cams.first : null;
      if (front == null) {
        _fail('Kamera tidak ditemukan di perangkat ini.');
        return;
      }
      final c = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _cam = c;
      _reset();
      await c.startImageStream(_onFrame);
      if (mounted) setState(() {});
    } catch (e) {
      _fail('Kamera gagal dibuka: $e');
    }
  }

  void _fail(String m) {
    if (mounted) setState(() => _fatal = m);
  }

  void _reset([String? msg]) {
    _openFrames = 0;
    _armed = false;
    _sawClosed = false;
    _deadline = null;
    _message = msg ?? 'Posisikan wajah Anda di dalam bingkai';
  }

  InputImage? _toInput(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(
      _cam!.description.sensorOrientation,
    );
    if (rotation == null || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _done || _capturing) return;
    _busy = true;
    try {
      final input = _toInput(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _done || _capturing) return;
      _evaluate(faces);
    } catch (_) {
      // lewati frame yang gagal
    } finally {
      _busy = false;
    }
  }

  void _evaluate(List<Face> faces) {
    if (faces.isEmpty) {
      _reset('Wajah tidak terlihat');
    } else if (faces.length > 1) {
      _reset('Hanya satu wajah dalam bingkai');
    } else {
      final l = faces.first.leftEyeOpenProbability;
      final r = faces.first.rightEyeOpenProbability;
      if (l == null || r == null) {
        _reset('Wajah belum jelas, perbaiki pencahayaan');
      } else {
        final open = l > 0.7 && r > 0.7;
        final closed = l < 0.25 && r < 0.25;
        if (!_armed) {
          _openFrames = open ? _openFrames + 1 : 0;
          if (_openFrames >= 5) {
            _armed = true;
            _deadline = DateTime.now().add(const Duration(seconds: 12));
            _message = 'Sekarang kedipkan mata Anda';
          } else {
            _message = 'Lihat ke kamera dengan mata terbuka';
          }
        } else if (DateTime.now().isAfter(_deadline!)) {
          _reset('Waktu habis, coba lagi');
        } else if (!_sawClosed && closed) {
          _sawClosed = true;
        } else if (_sawClosed && open) {
          _capture();
          return;
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _safeDelete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    if (mounted) setState(() => _message = 'Mengambil foto...');
    final cam = _cam!;
    try {
      await cam.stopImageStream();
      final file = await cam.takePicture();
      final faces = await _detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      final ok =
          faces.length == 1 &&
          (faces.first.leftEyeOpenProbability ?? 0) > 0.5 &&
          (faces.first.rightEyeOpenProbability ?? 0) > 0.5;
      if (!ok) {
        await _safeDelete(file.path);
        _capturing = false;
        _reset('Foto kurang jelas, ulangi');
        await cam.startImageStream(_onFrame);
        if (mounted) setState(() {});
        return;
      }
      final raw = await File(file.path).readAsBytes();
      await _safeDelete(file.path);
      final jpeg = await compute(_prepareJpeg, raw);
      _done = true;
      if (mounted) Navigator.pop(context, jpeg);
    } catch (e) {
      _fail('Gagal mengambil foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi wajah')),
      body: _fatal != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_fatal!, textAlign: TextAlign.center),
              ),
            )
          : cam == null || !cam.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 24),
                Center(
                  child: ClipOval(
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: cam.value.previewSize!.height,
                          height: cam.value.previewSize!.width,
                          child: CameraPreview(cam),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Foto hanya dipakai untuk verifikasi absensi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
