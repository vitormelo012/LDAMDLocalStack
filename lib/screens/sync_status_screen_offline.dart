import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider_offline.dart';
import '../services/sync_service_offline.dart';

class SyncStatusScreenOffline extends StatelessWidget {
  const SyncStatusScreenOffline({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status de Sincronização'),
      ),
      body: Consumer<TaskProviderOffline>(
        builder: (context, provider, child) {
          return FutureBuilder<SyncStats>(
            future: provider.getSyncStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snapshot.data!;
              final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(
                      title: 'Status da Rede',
                      icon: stats.isOnline ? Icons.wifi : Icons.wifi_off,
                      value: stats.isOnline ? 'Online' : 'Offline',
                      color: stats.isOnline ? Colors.green : Colors.red,
                    ),
                    _buildStatusCard(
                      title: 'Total de Tarefas',
                      icon: Icons.task,
                      value: stats.totalTasks.toString(),
                      color: Colors.blue,
                    ),
                    _buildStatusCard(
                      title: 'Tarefas Não Sincronizadas',
                      icon: Icons.sync_problem,
                      value: stats.unsyncedTasks.toString(),
                      color: stats.unsyncedTasks > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    _buildStatusCard(
                      title: 'Operações na Fila',
                      icon: Icons.queue,
                      value: stats.queuedOperations.toString(),
                      color: stats.queuedOperations > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    _buildStatusCard(
                      title: 'Última Sincronização',
                      icon: Icons.update,
                      value: stats.lastSync != null
                          ? dateFormat.format(stats.lastSync!)
                          : 'Nunca',
                      color: Colors.purple,
                    ),
                    _buildStatusCard(
                      title: 'Sincronizando',
                      icon: stats.isSyncing
                          ? Icons.sync
                          : Icons.check_circle_outline,
                      value: stats.isSyncing ? 'Sim' : 'Não',
                      color: stats.isSyncing ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: stats.isOnline && !stats.isSyncing
                          ? () => _handleSync(context, provider)
                          : null,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sincronizar Agora'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSync(
      BuildContext context, TaskProviderOffline provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Iniciando sincronização...'),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await provider.sync();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? '✅ ${result.message}' : '❌ ${result.message}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
