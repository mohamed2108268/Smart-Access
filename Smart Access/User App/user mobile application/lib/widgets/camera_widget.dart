// lib/widgets/camera_widget.dart
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';

class CameraWidget extends StatefulWidget {
  final Function(Uint8List) onImageCaptured;

  const CameraWidget({
    super.key,
    required this.onImageCaptured,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  html.VideoElement? _videoElement;
  bool _isCameraInitialized = false;
  bool _isCameraAvailable = false;
  String? _errorMessage;
  final String _viewId = 'camera-view-${DateTime.now().millisecondsSinceEpoch}';
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _registerViewFactory() {
    // Register a factory for the VideoElement
    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        _videoElement = html.VideoElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..autoplay = true
          ..muted = true
          ..controls = false;
        
        return _videoElement!;
      },
    );
  }

  Future<void> _initializeCamera() async {
    _registerViewFactory();
    
    // Add a small delay to ensure the view is registered
    Future.delayed(const Duration(milliseconds: 500), () {
      _startCamera();
    });
  }

  void _startCamera() async {
    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'user', // Front camera
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });

      if (mediaStream != null && _videoElement != null) {
        _videoElement!.srcObject = mediaStream;
        
        // Wait for the video to be ready
        _videoElement!.onLoadedMetadata.listen((event) {
          setState(() {
            _isCameraInitialized = true;
            _isCameraAvailable = true;
          });
        });
        
        // Start periodic check for video frames
        _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (_videoElement != null && 
              _videoElement!.videoWidth > 0 && 
              _videoElement!.videoHeight > 0) {
            setState(() {
              _isCameraInitialized = true;
              _isCameraAvailable = true;
            });
            timer.cancel();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera access denied or unavailable';
        _isCameraAvailable = false;
      });
      print('Camera error: $e');
    }
  }

  void _stopCamera() {
    if (_videoElement != null && _videoElement!.srcObject != null) {
      // Stop all tracks
      final mediaStream = _videoElement!.srcObject as html.MediaStream;
      mediaStream.getTracks().forEach((track) => track.stop());
      _videoElement!.srcObject = null;
    }
  }

  void _captureImage() {
    if (_videoElement == null || !_isCameraInitialized) return;

  // Create a canvas to capture the image
    final canvasElement = html.CanvasElement(
    // Reduce the size of the captured image
      width: 640, // Reduced width for smaller file size
      height: 480, // Reduced height for smaller file size
    );
  
  // Draw the current video frame to the canvas with resizing
    canvasElement.context2D.drawImageScaled(
      _videoElement!, 
      0, 0, 
      canvasElement.width!, 
      canvasElement.height!
  );
  
  // Convert to blob with higher compression (lower quality)
  canvasElement.toBlob('image/jpeg', 0.7).then((blob) { // Reduced quality to 70%
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    
    reader.onLoad.listen((event) {
      final result = reader.result;
      if (result is List<int>) {
        // Convert to Uint8List and pass to callback
        final uint8List = Uint8List.fromList(result);
        print('Captured image size: ${uint8List.length} bytes'); // Debug output
        widget.onImageCaptured(uint8List);
      }
    });
  });
}

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return AspectRatio(
        aspectRatio: 3/4,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 3/4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Camera view
          HtmlElementView(viewType: _viewId),
          
          // Face outline guide
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: FaceGuidePainter(),
              ),
            ),
          ),
          
          // Loading indicator
          if (!_isCameraInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          
          // Capture button
          if (_isCameraInitialized)
            Positioned(
              bottom: 20,
              child: FloatingActionButton(
                onPressed: _captureImage,
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera_alt, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - size.height * 0.05);
    final radius = size.width * 0.4;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    // Draw face outline circle
    canvas.drawCircle(center, radius, paint);
    
    // Draw guide text
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: Offset(1.0, 1.0),
          blurRadius: 3.0,
          color: Colors.black,
        ),
      ],
    );
    
    final textSpan = TextSpan(
      text: 'Position your face here',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );
    
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        center.dy + radius + 20,
      ),
    );
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) => false;
}