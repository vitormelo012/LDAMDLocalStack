import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_offline.dart';
import '../models/sync_operation.dart';

/// Serviço de gerenciamento do banco de dados SQLite local
class DatabaseServiceOffline {
  static final DatabaseServiceOffline instance = DatabaseServiceOffline._init();
  static Database? _database;

  DatabaseServiceOffline._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_manager_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // TEMPORÁRIO: Apagar banco antigo para forçar recriação com nova estrutura
    // Comentado após primeira execução bem-sucedida
    // try {
    //   await deleteDatabase(path);
    //   print('🗑️ Banco de dados antigo deletado');
    // } catch (e) {
    //   print('ℹ️ Nenhum banco antigo para deletar');
    // }

    return await openDatabase(
      path,
      version: 2, // Incrementar versão para forçar migração
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adicionar colunas novas à tabela tasks_offline
      await db.execute('ALTER TABLE tasks_offline ADD COLUMN photos TEXT');
      await db.execute('ALTER TABLE tasks_offline ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks_offline ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks_offline ADD COLUMN locationName TEXT');
      
      print('✅ Banco de dados atualizado para versão 2');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de tarefas
    await db.execute('''
      CREATE TABLE tasks_offline (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        syncStatus TEXT NOT NULL,
        localUpdatedAt INTEGER,
        photos TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT
      )
    ''');

    // Tabela de fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        taskId TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        retries INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        error TEXT
      )
    ''');

    // Tabela de metadados
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Índices para otimização
    await db.execute('CREATE INDEX idx_tasks_userId ON tasks_offline(userId)');
    await db.execute(
        'CREATE INDEX idx_tasks_syncStatus ON tasks_offline(syncStatus)');
    await db
        .execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');

    print('✅ Banco de dados criado com sucesso');
  }

  // ==================== OPERAÇÕES DE TAREFAS ====================

  /// Inserir ou atualizar tarefa
  Future<TaskOffline> upsertTask(TaskOffline task) async {
    final db = await database;
    await db.insert(
      'tasks_offline',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return task;
  }

  /// Buscar tarefa por ID
  Future<TaskOffline?> getTask(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks_offline',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return TaskOffline.fromMap(maps.first);
  }

  /// Buscar todas as tarefas
  Future<List<TaskOffline>> getAllTasks({String userId = 'user1'}) async {
    final db = await database;
    final maps = await db.query(
      'tasks_offline',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );

    return maps.map((map) => TaskOffline.fromMap(map)).toList();
  }

  /// Buscar tarefas não sincronizadas
  Future<List<TaskOffline>> getUnsyncedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks_offline',
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.pending.toString()],
    );

    return maps.map((map) => TaskOffline.fromMap(map)).toList();
  }

  /// Buscar tarefas com conflito
  Future<List<TaskOffline>> getConflictedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks_offline',
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.conflict.toString()],
    );

    return maps.map((map) => TaskOffline.fromMap(map)).toList();
  }

  /// Deletar tarefa
  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'tasks_offline',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atualizar status de sincronização
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'tasks_offline',
      {'syncStatus': status.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FILA DE SINCRONIZAÇÃO ====================

  /// Adicionar operação à fila
  Future<SyncOperation> addToSyncQueue(SyncOperation operation) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return operation;
  }

  /// Obter operações pendentes
  Future<List<SyncOperation>> getPendingSyncOperations() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncOperationStatus.pending.toString()],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => SyncOperation.fromMap(map)).toList();
  }

  /// Atualizar operação de sincronização
  Future<void> updateSyncOperation(SyncOperation operation) async {
    final db = await database;
    await db.update(
      'sync_queue',
      operation.toMap(),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }

  /// Remover operação da fila
  Future<int> removeSyncOperation(String id) async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Limpar operações concluídas
  Future<int> clearCompletedOperations() async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncOperationStatus.completed.toString()],
    );
  }

  // ==================== METADADOS ====================

  /// Salvar metadado
  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obter metadado
  Future<String?> getMetadata(String key) async {
    final db = await database;
    final maps = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  // ==================== ESTATÍSTICAS ====================

  /// Obter estatísticas do banco de dados
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;

    final totalTasks = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM tasks_offline')) ??
        0;

    final unsyncedTasks = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM tasks_offline WHERE syncStatus = ?',
            [SyncStatus.pending.toString()])) ??
        0;

    final queuedOperations = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
            [SyncOperationStatus.pending.toString()])) ??
        0;

    final lastSync = await getMetadata('lastSyncTimestamp');

    return {
      'totalTasks': totalTasks,
      'unsyncedTasks': unsyncedTasks,
      'queuedOperations': queuedOperations,
      'lastSync': lastSync != null ? int.parse(lastSync) : null,
    };
  }

  // ==================== UTILIDADES ====================

  /// Limpar todos os dados
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks_offline');
    await db.delete('sync_queue');
    await db.delete('metadata');
    print('🗑️ Todos os dados foram limpos');
  }

  /// Fechar banco de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
