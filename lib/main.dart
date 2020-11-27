import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:ext_storage/ext_storage.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ShowCamera(),
    );
  }
}

class ShowCamera extends StatefulWidget {
  @override
  _ShowCameraState createState() => _ShowCameraState();
}

class _ShowCameraState extends State<ShowCamera> {
  CameraController controller;
  List cameras;
  int selectedCameraIdx;
  String path;
  var _isLoading = false, imagePath;

  File _generatedImage;
  @override
  void initState() {
    super.initState();

    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        selectedCameraIdx = 1;

        _initCameraController(cameras[selectedCameraIdx]);
      } else {
        print("No camera available");
      }
    }).catchError((err) {
      print('Error: $err.code\nError Message: $err.message');
    });
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }

    controller = CameraController(cameraDescription, ResolutionPreset.high);

    controller.addListener(
      () {
        if (mounted) {
          setState(() {});
        }

        if (controller.value.hasError) {
          print('Camera error ${controller.value.errorDescription}');
        }
      },
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {}

    if (mounted) {
      setState(() {});
    }
  }

  getImage() async {
    try {
      final paths = join(
        (await getTemporaryDirectory()).path,
        '${DateTime.now()}.png',
      );
      DateTime time = new DateTime.now();

      setState(() {
        _isLoading = true;
      });
      await controller.takePicture(paths);
      imagePath = File(paths);
      // final directory = await getExternalStorageDirectory();
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      final directory = await ExtStorage.getExternalStorageDirectory();
      final Directory directoryFolder = Directory('$directory/thermo');

      final Directory directoryNewFolder = await directoryFolder.create(
        recursive: true,
      );
      print(directoryNewFolder.path);
      path = directoryNewFolder.path;
      final File newImage = await imagePath.copy('$path/$time.png');

      _generatedImage = newImage;
      save();
    } catch (e) {
      print(e);
    }
  }

  save() async {
    // await controller.dispose();
    await GallerySaver.saveImage(_generatedImage.path);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    //get data of bluetooth resp
    return Scaffold(
      appBar: AppBar(
        title: Text('Thermo SCRSHT'),
      ),
      body: Column(
        children: [
          _isLoading
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Container(
                  width: MediaQuery.of(context).size.width,
                  child: _cameraPreviewWidget(),
                ),
          SizedBox(height: 10),
          RaisedButton(
            onPressed: () {
              // takeScreenShot();
              getImage();
            },
            child: Text('Save'),
            color: Colors.amber,
          )
        ],
      ),
    );
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Loading',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.0,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio * 1.3,
      child: CameraPreview(controller),
    );
  }
}
