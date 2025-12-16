import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider_offline.dart';
import '../models/task_offline.dart';
import '../models/sync_operation.dart';
import '../services/connectivity_service_offline.dart';
import 'task_form_screen_offline.dart';
import 'sync_status_screen_offline.dart';

class HomeScreenOffline extends StatefulWidget {
  const HomeScreenOffline({super.key});

  @override
  State<HomeScreenOffline> createState() => _HomeScreenOfflineState();
}

class _HomeScreenOfflineState extends State<HomeScreenOffline> {
  final _connectivity = ConnectivityServiceOffline.instance;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _setupSyncListener();
  }

  void _setupSyncListener() {
    // Escutar eventos de sincronização do provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = context.read<TaskProviderOffline>();
      provider.syncStatusStream.listen((event) {
        if (!mounted) return;

        if (event.type == SyncEventType.conflictResolved) {
          final taskId = event.data!['taskId'] as String?;
          final resolution = event.data!['resolution'] as String?;
          if (taskId != null && resolution != null) {
            _showConflictDialog(taskId, resolution);
          }
        } else if (event.type == SyncEventType.syncCompleted) {
          final pushedCount = event.data!['pushedCount'] as int? ?? 0;
          final pulledCount = event.data!['pulledCount'] as int? ?? 0;
          _showSnackBar(
            '✅ Sincronização concluída: $pushedCount enviadas, $pulledCount recebidas',
            Colors.green,
          );
        } else if (event.type == SyncEventType.syncError) {
          final error = event.data!['error'] as String? ?? 'Erro desconhecido';
          _showSnackBar(
            '❌ Erro na sincronização: $error',
            Colors.red,
          );
        }
      });
    });
  }

  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    if (!mounted) return;

    setState(() => _isOnline = _connectivity.isOnline);

    // Escutar mudanças de conectividade
    _connectivity.connectivityStream.listen((isOnline) {
      if (!mounted) return;

      setState(() => _isOnline = isOnline);

      if (isOnline) {
        _showSnackBar('🟢 Conectado - Sincronizando...', Colors.green);
        context.read<TaskProviderOffline>().sync();
      } else {
        _showSnackBar('🔴 Modo Offline', Colors.orange);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas Offline-First'),
        actions: [
          // Indicador de conectividade
          _buildConnectivityIndicator(),

          // Botão de sincronização manual
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isOnline ? _handleManualSync : null,
            tooltip: 'Sincronizar',
          ),

          // Botão de estatísticas
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _navigateToSyncStatus(),
            tooltip: 'Status de Sincronização',
          ),
        ],
      ),
      body: Consumer<TaskProviderOffline>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro: ${taskProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => taskProvider.loadTasks(),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final tasks = taskProvider.tasks;

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma tarefa',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para criar uma nova',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => taskProvider.sync(),
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(tasks[index], taskProvider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToTaskForm,
        tooltip: 'Nova Tarefa',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConnectivityIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isOnline ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskOffline task, TaskProviderOffline provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (_) => provider.toggleCompleted(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildPriorityBadge(task.priority),
                const SizedBox(width: 8),
                _buildSyncStatusBadge(task.syncStatus),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToTaskForm(task: task),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(task, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(SyncStatus status) {
    IconData icon;
    String tooltip;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.check_circle;
        tooltip = 'Sincronizado';
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_off;
        tooltip = 'Pendente de sincronização';
        break;
      case SyncStatus.conflict:
        icon = Icons.warning;
        tooltip = 'Conflito detectado';
        break;
      case SyncStatus.error:
        icon = Icons.error;
        tooltip = 'Erro na sincronização';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 16,
        color: _getSyncStatusColor(status),
      ),
    );
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.pending:
        return Colors.orange;
      case SyncStatus.conflict:
        return Colors.red;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  Future<void> _handleManualSync() async {
    final provider = context.read<TaskProviderOffline>();

    _showSnackBar('🔄 Sincronizando...', Colors.blue);

    final result = await provider.sync();

    if (result.success) {
      _showSnackBar(
        '✅ Sincronização concluída',
        Colors.green,
      );
    } else {
      _showSnackBar(
        '❌ Erro na sincronização',
        Colors.red,
      );
    }
  }

  void _navigateToTaskForm({TaskOffline? task}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskFormScreenOffline(task: task),
      ),
    );
  }

  void _navigateToSyncStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SyncStatusScreenOffline(),
      ),
    );
  }

  Future<void> _confirmDelete(
      TaskOffline task, TaskProviderOffline provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja deletar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteTask(task.id);
      if (mounted) {
        _showSnackBar('🗑️ Tarefa deletada', Colors.grey);
      }
    }
  }

  void _showConflictDialog(String taskId, String resolution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conflito Resolvido'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Um conflito foi detectado e resolvido automaticamente usando a estratégia Last-Write-Wins (última escrita vence).',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resolução:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resolution,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
