import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';

class CustomCamera extends StatefulWidget {
  @override
  _CustomCameraState createState() => _CustomCameraState();
}

class _CustomCameraState extends State<CustomCamera>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  String filePath = '';
  final int cameraDirection = 1;
  double width = 200;
  double height = 200;

  void _camera() async {
    cameras = await availableCameras();
    if (cameras.isNotEmpty && cameras.length >= 2) {
      controller = CameraController(
          cameras[cameraDirection], ResolutionPreset.high,
          imageFormatGroup: ImageFormatGroup.jpeg);
      controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    }
  }

  @override
  void initState() {
    // 添加监听器。生命周期变化，会回调到didChangeAppLifecycleState方法。
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _camera();
  }

  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 监听应用维度的生命周期变化。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('state = $state');
    if (state == AppLifecycleState.paused) {
      print("app进入后台：paused");
      controller?.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      print("app进入前台：resumed");
      controller?.resumePreview();
    } else if (state == AppLifecycleState.inactive) {
      // 不常用：应用程序处于非活动状态，并且为接收用户输入时调用，比如：来电话了。
      print("app inactive");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: cameras.isEmpty || controller == null
            ? Container(
                child: Center(
                  child: Text("loading..."),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (filePath.isNotEmpty)
                      Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2)),
                          child: ClipOval(
                              child: Image.file(File(filePath),
                                  width: width / 2,
                                  height: height / 2,
                                  fit: BoxFit.cover))),
                    SizedBox(
                      height: 20,
                    ),
                    Container(
                      width: width,
                      height: height,
                      alignment: Alignment.center,
                      child: _cameraScan(),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                        onPressed: onTakePictureButtonPressed,
                        child: Text('take photo')),
                    SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ));
  }

  Widget _cameraScan() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: EdgeInsets.all(2),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2)),
      child: _cameraPreviewWidget(),
    );
  }

  Widget _cameraPreviewWidget() {
    return ClipOval(
      child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle),
          child: AspectRatio(
              aspectRatio: 1,
              child: CameraPreview(
                controller!,
              ))),
    );
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        if (filePath != null) {
          setState(() {
            this.filePath = filePath;
          });
        }
      }
    });
  }

  Future<String> takePicture() async {
    if (controller == null) return "";
    if (!controller!.value.isInitialized) {
      return "";
    }

    if (controller!.value.isTakingPicture) {
      return "";
    }

    //前置摄像头拍出来的图片是反的 通过image_editor插件和flutter_native_image插件处理
    try {
      XFile file = await controller!.takePicture();
      String path = file.path;
      File tempFile;

      Uint8List? bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);

      if (cameras[cameraDirection].lensDirection == CameraLensDirection.front) {
        /// 前置摄像头处理，后置摄像头一般不会出现问题
        ImageEditorOption option = ImageEditorOption();
        /// 翻转配置
        option.addOption(FlipOption(horizontal: true));
        bytes = await ImageEditor.editImage(
            image: bytes!, imageEditorOption: option);

        await File(path).delete();
        tempFile = File(path);
        tempFile.writeAsBytesSync(bytes!);
        // 如果截图图片 注释掉该行代码，执行下面代码
        return tempFile.path;
      }

      /// 截取图片
      var offset = (image!.height - image.width) / 2;
      ImageProperties properties =
          await FlutterNativeImage.getImageProperties(path);
      properties.orientation = ImageOrientation.flipHorizontal;
      File cropedFile = await FlutterNativeImage.cropImage(
          file.path, 0, offset.round(), image.width, image.width);
      // img.bakeOrientation(image);
      return cropedFile.path;
    } on CameraException catch (e) {
      print(e.toString());
      return '';
    }
  }

  //前置摄像头拍出来的图片是反的
  //  Future<String> takePicture() async {
  //    if (!controller!.value.isInitialized) {
  //      print('Error: select a camera first.');
  //      return '';
  //    }
  //    if (controller!.value.isTakingPicture) {
  //      // A capture is already pending, do nothing.
  //      return '';
  //    }
  //    try {
  //      var ret = await controller!.takePicture();
  //      return ret.path;
  //    } on CameraException catch (e) {
  //      print("出现异常$e");
  //      return '';
  //    }
  //  }
}
