import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      print(
          '✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)');
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  // Verificar e solicitar permissão de câmera
  Future<bool> _checkCameraPermission(BuildContext context) async {
    print('🔍 Verificando permissão de câmera...');
    final status = await Permission.camera.status;
    print('🔍 Status de permissão de câmera: $status');

    if (status.isGranted) {
      print('✅ Permissão de câmera já concedida');
      return true;
    }

    if (status.isDenied) {
      print('⚠️ Permissão de câmera negada, solicitando...');
      final result = await Permission.camera.request();
      print('🔍 Resultado da solicitação: $result');
      if (result.isGranted) {
        print('✅ Permissão de câmera concedida');
        return true;
      }
    }

    if (status.isPermanentlyDenied || status.isDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Permissão de câmera necessária. Por favor, ative nas configurações.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Configurações',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    return false;
  }

  // Verificar e solicitar permissão de galeria
  Future<bool> _checkStoragePermission(BuildContext context) async {
    // Para Android 13+ (API 33+), usar photos permission
    if (Platform.isAndroid) {
      final androidInfo = await Permission.photos.status;

      if (androidInfo.isGranted) {
        return true;
      }

      if (androidInfo.isDenied) {
        final result = await Permission.photos.request();
        if (result.isGranted) {
          return true;
        }

        // Tentar storage para versões antigas do Android
        final storageResult = await Permission.storage.request();
        if (storageResult.isGranted) {
          return true;
        }
      }

      if (androidInfo.isPermanentlyDenied || androidInfo.isDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Permissão de galeria necessária. Por favor, ative nas configurações.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Configurações',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return false;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Permissão de galeria necessária. Por favor, ative nas configurações.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Configurações',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return false;
      }
    }

    return false;
  }

  Future<String?> takePicture(BuildContext context) async {
    print('📸 Iniciando takePicture...');

    // Verificar permissão de câmera primeiro
    final hasPermission = await _checkCameraPermission(context);
    if (!hasPermission) {
      print('❌ Permissão de câmera negada');
      return null;
    }

    if (!hasCameras) {
      print('❌ Nenhuma câmera disponível');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nenhuma câmera disponível'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    print('✅ Inicializando câmera: ${_cameras!.first.name}');
    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);

      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final savedImage = await File(image.path).copy(savePath);
      print('✅ Foto salva: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }

  // GALERIA DE FOTOS
  Future<String?> pickFromGallery(BuildContext context) async {
    print('🖼️ Iniciando pickFromGallery...');

    // Verificar permissão de galeria primeiro
    final hasPermission = await _checkStoragePermission(context);
    if (!hasPermission) {
      print('❌ Permissão de galeria negada');
      return null;
    }

    print('✅ Abrindo seletor de imagens...');
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        print('⚠️ Nenhuma imagem selecionada');
        return null;
      }

      print('✅ Imagem selecionada: ${image.path}');
      final savedPath = await savePicture(image);
      print('✅ Imagem salva em: $savedPath');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Foto selecionada da galeria!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return savedPath;
    } catch (e) {
      print('❌ Erro ao selecionar da galeria: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao acessar galeria: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    }
  }

  // DIALOG PARA ESCOLHER ENTRE CÂMERA E GALERIA
  Future<String?> showPhotoSourceDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Adicionar Foto',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Tirar Foto'),
                subtitle: const Text('Use a câmera do dispositivo'),
                onTap: () async {
                  final photoPath = await takePicture(context);
                  if (context.mounted) {
                    Navigator.pop(context, photoPath);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Escolher da Galeria'),
                subtitle: const Text('Selecione uma foto existente'),
                onTap: () async {
                  final photoPath = await pickFromGallery(context);
                  if (context.mounted) {
                    Navigator.pop(context, photoPath);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close, color: Colors.red),
                ),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
