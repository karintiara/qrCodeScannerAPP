import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras(); // Inisialisasi kamera dulu
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: QRScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});
  @override
  State<StatefulWidget> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  CameraController? cameraController;
  Barcode? result;
  bool isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = isFrontCamera ? cameras[1] : cameras[0];
    cameraController = CameraController(camera, ResolutionPreset.medium);
    await cameraController?.initialize();
    setState(() {});
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      qrController?.pauseCamera();
    }
    qrController?.resumeCamera();
  }

  @override
  void dispose() {
    qrController?.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSaveImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    final XFile file = await cameraController!.takePicture();
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await file.saveTo(path);
    await GallerySaver.saveImage(path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gambar QR disimpan ke galeri')),
    );
  }

  void _copyResultToClipboard() {
    if (result != null) {
      Clipboard.setData(ClipboardData(text: result!.code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil scan disalin ke clipboard')),
      );
    }
  }

  Future<void> _toggleCamera() async {
    isFrontCamera = !isFrontCamera;
    await qrController?.flipCamera();
    await cameraController?.dispose();
    await _initCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                if (cameraController != null && cameraController!.value.isInitialized)
                  CameraPreview(cameraController!),
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.green,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 250,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                if (result != null)
                  Text('Result: ${result!.code}', style: const TextStyle(fontSize: 18))
                else
                  const Text('Scan a code', style: TextStyle(fontSize: 18)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleCamera,
                      icon: const Icon(Icons.switch_camera),
                      label: const Text('Switch Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _captureAndSaveImage,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Image'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _copyResultToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Result'),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }
}
