import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class S3Service {
  // URL do backend - altere conforme necessário
  static const String baseUrl = 'http://192.168.1.47:3000'; // IP da máquina (para emulador Android)
  // static const String baseUrl = 'http://10.0.2.2:3000'; // Para emulador Android (se backend não estiver no Docker)
  // static const String baseUrl = 'http://localhost:3000'; // Para iOS/Desktop
  
  /// Faz upload de uma imagem para o S3 via backend
  /// 
  /// [imagePath] - Caminho local da imagem
  /// Retorna a URL da imagem no S3 ou null em caso de erro
  Future<String?> uploadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      
      if (!await file.exists()) {
        print('❌ Arquivo não encontrado: $imagePath');
        return null;
      }

      // Ler o arquivo como bytes
      final bytes = await file.readAsBytes();
      
      // Converter para base64
      final base64Image = base64Encode(bytes);
      
      // Determinar o tipo MIME
      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.jpg') || 
                 imagePath.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      }

      print('📤 Enviando imagem para S3...');
      
      // Fazer requisição POST para o backend
      final response = await http.post(
        Uri.parse('$baseUrl/upload-base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'mimeType': mimeType,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout ao fazer upload da imagem');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['url'] as String?;
        
        print('✅ Imagem enviada com sucesso!');
        print('🔗 URL: $imageUrl');
        
        return imageUrl;
      } else {
        print('❌ Erro ao fazer upload: ${response.statusCode}');
        print('Resposta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erro ao fazer upload da imagem: $e');
      return null;
    }
  }

  /// Faz upload de múltiplas imagens
  /// 
  /// Retorna um mapa com o caminho local como chave e a URL S3 como valor
  Future<Map<String, String?>> uploadMultipleImages(List<String> imagePaths) async {
    final results = <String, String?>{};
    
    for (final imagePath in imagePaths) {
      final url = await uploadImage(imagePath);
      results[imagePath] = url;
    }
    
    return results;
  }

  /// Verifica se o backend está disponível
  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(
        const Duration(seconds: 5),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Backend não está disponível: $e');
      return false;
    }
  }

  /// Lista todas as imagens do bucket S3
  Future<List<Map<String, dynamic>>> listImages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/images'),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['images'] as List;
        return images.cast<Map<String, dynamic>>();
      } else {
        print('❌ Erro ao listar imagens: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erro ao listar imagens: $e');
      return [];
    }
  }
}
