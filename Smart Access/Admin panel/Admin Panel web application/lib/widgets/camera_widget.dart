import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui' as ui;

class CameraWidget extends StatefulWidget {
  final Function(Uint8List) onImageCaptured;
  final Uint8List? capturedImage;

  const CameraWidget({
    super.key,
    required this.onImageCaptured,
    this.capturedImage,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  late html.VideoElement _videoElement;
  String _viewId = 'camera-view-${DateTime.now().millisecondsSinceEpoch}';
  bool _cameraInitialized = false;
  bool _isCameraAvailable = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  void _initializeCamera() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.objectFit = 'cover'
      ..style.width = '100%'
      ..style.height = '100%';

    // Register view factory
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      return _videoElement;
    });

    _startCamera();
  }

  void _startCamera() async {
    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'user',
        },
        'audio': false,
      });

      _videoElement.srcObject = mediaStream;
      setState(() {
        _cameraInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isCameraAvailable = false;
      });
      print('Error initializing camera: $e');
    }
  }

  void _stopCamera() {
    if (_videoElement.srcObject != null) {
      _videoElement.srcObject!.getTracks().forEach((track) => track.stop());
      _videoElement.srcObject = null;
    }
  }

  void _captureImage() {
    if (!_cameraInitialized) return;

    final canvasElement = html.CanvasElement(
      width: _videoElement.videoWidth,
      height: _videoElement.videoHeight,
    );
    canvasElement.context2D.drawImage(_videoElement, 0, 0);
    
    final dataUrl = canvasElement.toDataUrl('image/jpeg', 0.8);
    final base64 = dataUrl.split(',')[1];
    final bytes = _base64ToBytes(base64);
    
    widget.onImageCaptured(bytes);
  }

  Uint8List _base64ToBytes(String base64) {
    final List<int> bytes = html.window.atob(base64).codeUnits;
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.capturedImage != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              widget.capturedImage!,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _startCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake Photo'),
          ),
        ],
      );
    }

    if (!_isCameraAvailable) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Camera not available',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please ensure you have given camera permissions',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startCamera,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: _cameraInitialized
              ? HtmlElementView(viewType: _viewId)
              : const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _captureImage,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capture Photo'),
        ),
      ],
    );
  }
}