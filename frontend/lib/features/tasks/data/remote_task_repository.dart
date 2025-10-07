import '../../../core/network/api_client.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/task.dart';
import 'task_repository.dart';

class RemoteTaskRepository extends TaskSessionRepository {
  RemoteTaskRepository(super.session, this._client);

  final ApiClient _client;

  @override
  Future<TaskCollection> fetchTasks({TaskQuery? query}) async {
    final user = _requireUser();
    final buffer = StringBuffer('/tasks/?user_id=${Uri.encodeComponent(user.id)}');
    if (query != null) {
      if (query.statuses != null && query.statuses!.isNotEmpty) {
        for (final status in query.statuses!) {
          buffer.write('&status=${Uri.encodeComponent(_mapStatus(status))}');
        }
      }
      if (query.priorities != null && query.priorities!.isNotEmpty) {
        for (final priority in query.priorities!) {
          buffer.write('&priority=${Uri.encodeComponent(priority.name)}');
        }
      }
      if (query.tags != null && query.tags!.isNotEmpty) {
        for (final tag in query.tags!) {
          buffer.write('&tags=${Uri.encodeComponent(tag)}');
        }
      }
      if (query.dueFrom != null) {
        buffer.write('&due_from=${Uri.encodeComponent(query.dueFrom!.toIso8601String())}');
      }
      if (query.dueTo != null) {
        buffer.write('&due_to=${Uri.encodeComponent(query.dueTo!.toIso8601String())}');
      }
      if (query.search != null && query.search!.isNotEmpty) {
        buffer.write('&search=${Uri.encodeComponent(query.search!.trim())}');
      }
      if (query.skip > 0) {
        buffer.write('&skip=${query.skip}');
      }
      if (query.limit != 100) {
        buffer.write('&limit=${query.limit}');
      }
    }
    final response = await _client.getJson(buffer.toString());
    final payload = _unwrap(response);
    return TaskCollection.fromJson(payload);
  }

  @override
  Future<Task> fetchTask(String id) async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/tasks/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
    );
    final payload = _unwrap(response);
    return Task.fromJson(payload);
  }

  @override
  Future<Task> createTask(TaskDraft draft) async {
    final user = _requireUser();
    draft.userId = user.id;
    final response = await _client.postJson('/tasks/', draft.toCreatePayload());
    final payload = _unwrap(response);
    return Task.fromJson(payload);
  }

  @override
  Future<Task> updateTask(String id, TaskDraft draft) async {
    final user = _requireUser();
    final response = await _client.putJson(
      '/tasks/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
      draft.toUpdatePayload(),
    );
    final payload = _unwrap(response);
    return Task.fromJson(payload);
  }

  @override
  Future<void> deleteTask(String id) async {
    final user = _requireUser();
    await _client.delete(
      '/tasks/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
    );
  }

  @override
  Future<List<Task>> bulkComplete(List<String> taskIds, {bool completed = true}) async {
    final user = _requireUser();
    final response = await _client.postJson(
      '/tasks/bulk-complete?user_id=${Uri.encodeComponent(user.id)}',
      {
        'task_ids': taskIds,
        'completed': completed,
      },
    );
    final payload = _unwrapList(response);
    return payload.map(Task.fromJson).toList(growable: false);
  }

  @override
  Future<TaskStatistics> fetchStatistics() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/tasks/stats?user_id=${Uri.encodeComponent(user.id)}',
    );
    final payload = _unwrap(response);
    return TaskStatistics.fromJson(payload);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return json;
  }

  List<Map<String, dynamic>> _unwrapList(Map<String, dynamic> json) {
    if (json['items'] is List) {
      return (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return [];
  }

  AuthUser _requireUser() {
    final user = session.currentUser;
    if (user == null) {
      throw StateError('Task operation requires authenticated user');
    }
    return user;
  }

  String _mapStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
      case TaskStatus.pending:
        return 'pending';
    }
  }
}
