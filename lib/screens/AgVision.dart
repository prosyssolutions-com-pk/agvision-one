import 'dart:io';
import 'package:agvision_scanner/screens/history_screen.dart';
import 'package:agvision_scanner/services/gemini_vision_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AgVision extends StatefulWidget {
  const AgVision({super.key});

  @override
  State<AgVision> createState() => _AgVisionState();
}

class _AgVisionState extends State<AgVision> {
  CameraController? _cameraController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady =
        _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          "AgVision One",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 28),
            tooltip: "View Scan History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: isReady
          ? Stack(
              children: [
                SizedBox.expand(child: CameraPreview(_cameraController!)),
                if (_isUploading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            "Uploading & Analyzing Produce...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.green)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : snapAndSavePhoto,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: Text(
          _isUploading ? "Processing..." : "Scan Produce",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> snapAndSavePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Capture photo
      XFile temporaryPhoto = await _cameraController!.takePicture();
      File imageFile = File(temporaryPhoto.path);

      // 2. UPLOAD FIRST (Compressed): Shrink photo so Supabase uploads in <1 second
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 640,
        minHeight: 640,
        quality: 75,
      );
      final finalBytes = compressedBytes ?? await imageFile.readAsBytes();

      String fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final supabase = Supabase.instance.client;
      await supabase.storage
          .from('veg_fruit_scans')
          .uploadBinary(fileName, finalBytes);

      final String publicImageUrl = supabase.storage
          .from('veg_fruit_scans')
          .getPublicUrl(fileName);

      // 3. Insert initial record and get its database 'id'
      final insertedRow = await supabase
          .from('sorting_logs')
          .insert({
            'produce_name': 'Analyzing...',
            'grade_rating': 'Grade B',
            'texture_score': 0.0,
            'photo_url': publicImageUrl,
          })
          .select()
          .single();

      final int rowId = insertedRow['id'];

      // 4. SCAN SECOND: Send tiny ~15KB compressed copy to Gemini Vision AI
      final aiResult = await GeminiVisionService.analyzeProduce(imageFile);
      final String produceName = aiResult['produce_name'] ?? 'Unknown';
      final String gradeRating = aiResult['grade_rating'] ?? 'Reject';
      final double textureScore = (aiResult['texture_score'] as num).toDouble();

      // 5. Update the Supabase row with real AI grading results
      await supabase
          .from('sorting_logs')
          .update({
            'produce_name': produceName,
            'grade_rating': gradeRating,
            'texture_score': textureScore,
          })
          .eq('id', rowId);

      // 6. Display result banner
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "AI Verified: $produceName ($gradeRating - $textureScore%)",
          ),
          backgroundColor: gradeRating == 'Grade A'
              ? Colors.green
              : (gradeRating == 'Grade B' ? Colors.orange : Colors.red),
        ),
      );
    } catch (errorDetails) {
      debugPrint("Pipeline Error: $errorDetails");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Photo saved, AI notice: $errorDetails"),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}
