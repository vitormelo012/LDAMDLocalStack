const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar CORS para aceitar requisições do Flutter
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Configurar cliente S3 para LocalStack
const s3Client = new S3Client({
  endpoint: process.env.AWS_ENDPOINT || 'http://localstack:4566',
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  },
  forcePathStyle: true, // Necessário para LocalStack
});

const BUCKET_NAME = process.env.S3_BUCKET || 'shopping-images';

// Configurar multer para upload em memória
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  }
});

// Endpoint de health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Backend está rodando!' });
});

// Endpoint para upload de imagens (Multipart)
app.post('/upload', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Nenhuma imagem foi enviada' });
    }

    // Gerar nome único para a imagem
    const fileExtension = req.file.mimetype.split('/')[1];
    const fileName = `${uuidv4()}.${fileExtension}`;

    // Upload para S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: fileName,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
    });

    await s3Client.send(command);

    const imageUrl = `http://localhost:4566/${BUCKET_NAME}/${fileName}`;

    console.log(`✅ Imagem ${fileName} enviada com sucesso para o S3!`);

    res.json({
      success: true,
      message: 'Imagem enviada com sucesso!',
      fileName: fileName,
      url: imageUrl,
    });
  } catch (error) {
    console.error('❌ Erro ao fazer upload:', error);
    res.status(500).json({ 
      error: 'Erro ao fazer upload da imagem',
      details: error.message 
    });
  }
});

// Endpoint para upload de imagens (Base64)
app.post('/upload-base64', async (req, res) => {
  try {
    const { image, mimeType } = req.body;

    if (!image) {
      return res.status(400).json({ error: 'Nenhuma imagem foi enviada' });
    }

    // Remover prefixo data:image/...;base64, se presente
    const base64Data = image.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    // Determinar extensão do arquivo
    const extension = mimeType ? mimeType.split('/')[1] : 'jpg';
    const fileName = `${uuidv4()}.${extension}`;

    // Upload para S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: fileName,
      Body: buffer,
      ContentType: mimeType || 'image/jpeg',
    });

    await s3Client.send(command);

    const imageUrl = `http://localhost:4566/${BUCKET_NAME}/${fileName}`;

    console.log(`✅ Imagem ${fileName} enviada com sucesso para o S3!`);

    res.json({
      success: true,
      message: 'Imagem enviada com sucesso!',
      fileName: fileName,
      url: imageUrl,
    });
  } catch (error) {
    console.error('❌ Erro ao fazer upload:', error);
    res.status(500).json({ 
      error: 'Erro ao fazer upload da imagem',
      details: error.message 
    });
  }
});

// Endpoint para listar imagens do bucket
app.get('/images', async (req, res) => {
  try {
    const command = new ListObjectsV2Command({
      Bucket: BUCKET_NAME,
    });

    const response = await s3Client.send(command);

    const images = (response.Contents || []).map(item => ({
      fileName: item.Key,
      size: item.Size,
      lastModified: item.LastModified,
      url: `http://localhost:4566/${BUCKET_NAME}/${item.Key}`,
    }));

    res.json({
      success: true,
      count: images.length,
      images: images,
    });
  } catch (error) {
    console.error('❌ Erro ao listar imagens:', error);
    res.status(500).json({ 
      error: 'Erro ao listar imagens',
      details: error.message 
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando na porta ${PORT}`);
  console.log(`📦 Bucket S3: ${BUCKET_NAME}`);
  console.log(`☁️  Endpoint LocalStack: ${process.env.AWS_ENDPOINT || 'http://localstack:4566'}`);
});
