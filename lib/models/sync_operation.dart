import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Operação de sincronização pendente
class SyncOperation {
  final String id;
  final OperationType type;
  final String taskId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retries;
  final SyncOperationStatus status;
  final String? error;

  SyncOperation({
    String? id,
    required this.type,
    required this.taskId,
    required this.data,
    DateTime? timestamp,
    this.retries = 0,
    this.status = SyncOperationStatus.pending,
    this.error,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Criar cópia com modificações
  SyncOperation copyWith({
    OperationType? type,
    String? taskId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retries,
    SyncOperationStatus? status,
    String? error,
  }) {
    return SyncOperation(
      id: id,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retries: retries ?? this.retries,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  /// Converter para Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'taskId': taskId,
      'data': jsonEncode(data),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retries': retries,
      'status': status.toString(),
      'error': error,
    };
  }

  /// Criar a partir de Map
  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'],
      type: OperationType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      taskId: map['taskId'],
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      retries: map['retries'],
      status: SyncOperationStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
      ),
      error: map['error'],
    );
  }

  @override
  String toString() {
    return 'SyncOperation(type: $type, taskId: $taskId, status: $status)';
  }
}

/// Tipo de operação
enum OperationType {
  create,
  update,
  delete,
}

/// Status da operação de sincronização
enum SyncOperationStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Tipo de evento de sincronização
enum SyncEventType {
  syncStarted,
  syncCompleted,
  syncError,
  conflictResolved,
}

/// Evento de sincronização
class SyncEvent {
  final SyncEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SyncEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncEvent.syncStarted() {
    return SyncEvent(type: SyncEventType.syncStarted, data: {});
  }

  factory SyncEvent.syncCompleted({
    required int pushedCount,
    required int pulledCount,
  }) {
    return SyncEvent(
      type: SyncEventType.syncCompleted,
      data: {
        'pushedCount': pushedCount,
        'pulledCount': pulledCount,
      },
    );
  }

  factory SyncEvent.syncError(String error) {
    return SyncEvent(
      type: SyncEventType.syncError,
      data: {'error': error},
    );
  }

  factory SyncEvent.conflictResolved({
    required String taskId,
    required String resolution,
  }) {
    return SyncEvent(
      type: SyncEventType.conflictResolved,
      data: {
        'taskId': taskId,
        'resolution': resolution,
      },
    );
  }

  @override
  String toString() {
    return 'SyncEvent(type: $type, data: $data)';
  }
}
