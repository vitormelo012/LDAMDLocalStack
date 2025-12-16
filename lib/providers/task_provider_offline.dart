import 'package:flutter/foundation.dart';
import '../models/task_offline.dart';
import '../models/sync_operation.dart';
import '../services/database_service_offline.dart';
import '../services/sync_service_offline.dart';
import '../services/connectivity_service_offline.dart';

/// Provider para gerenciamento de estado de tarefas
class TaskProviderOffline with ChangeNotifier {
  final DatabaseServiceOffline _db = DatabaseServiceOffline.instance;
  final SyncServiceOffline _syncService;
  final ConnectivityServiceOffline _connectivity = ConnectivityServiceOffline.instance;

  List<TaskOffline> _tasks = [];
  bool _isLoading = false;
  String? _error;
  bool _isOnline = false;

  TaskProviderOffline({String userId = 'user1'})
      : _syncService = SyncServiceOffline(userId: userId);

  // Getters
  List<TaskOffline> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;
  Stream<SyncEvent> get syncStatusStream => _syncService.syncStatusStream;

  List<TaskOffline> get completedTasks =>
      _tasks.where((task) => task.completed).toList();

  List<TaskOffline> get pendingTasks =>
      _tasks.where((task) => !task.completed).toList();

  List<TaskOffline> get unsyncedTasks =>
      _tasks.where((task) => task.syncStatus == SyncStatus.pending).toList();

  // ==================== INICIALIZAÇÃO ====================

  Future<void> initialize() async {
    // Inicializar conectividade
    await _connectivity.initialize();
    _isOnline = _connectivity.isOnline;
    
    await loadTasks();

    // Monitorar conectividade
    _connectivity.connectivityStream.listen((isConnected) {
      _isOnline = isConnected;
      notifyListeners();
    });

    // Iniciar auto-sync
    _syncService.startAutoSync();

    // Escutar eventos de sincronização
    _syncService.syncStatusStream.listen((event) {
      if (event.type == SyncEventType.syncCompleted) {
        loadTasks(); // Recarregar tarefas após sync
      }
    });
  }

  // ==================== OPERAÇÕES DE TAREFAS ====================

  /// Carregar todas as tarefas
  Future<void> loadTasks() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _tasks = await _db.getAllTasks();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obter todas as tarefas (alias para compatibilidade)
  Future<List<TaskOffline>> getTasks() async {
    return await _db.getAllTasks();
  }

  /// Criar nova tarefa (sobrecarga para aceitar TaskOffline)
  Future<void> createTask(TaskOffline task) async {
    try {
      await _syncService.createTask(task);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Criar nova tarefa (método original)
  Future<void> createTaskFromParams({
    required String title,
    required String description,
    String priority = 'medium',
  }) async {
    try {
      final task = TaskOffline(
        title: title,
        description: description,
        priority: priority,
      );

      await _syncService.createTask(task);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Atualizar tarefa
  Future<void> updateTask(TaskOffline task) async {
    try {
      await _syncService.updateTask(task);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Alternar status de conclusão
  Future<void> toggleCompleted(TaskOffline task) async {
    await updateTask(task.copyWith(completed: !task.completed));
  }

  /// Deletar tarefa
  Future<void> deleteTask(String taskId) async {
    try {
      await _syncService.deleteTask(taskId);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ==================== SINCRONIZAÇÃO ====================

  /// Sincronizar manualmente
  Future<SyncResult> sync() async {
    final result = await _syncService.sync();
    await loadTasks();
    return result;
  }

  /// Sincronizar manualmente (alias)
  Future<void> manualSync() async {
    await sync();
  }

  /// Obter estatísticas de sincronização
  Future<SyncStats> getSyncStats() async {
    return await _syncService.getStats();
  }

  // ==================== LIMPEZA ====================

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
