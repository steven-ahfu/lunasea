import 'package:dio/dio.dart';

/// Wait for an item refresh before reading its updated metadata.
Future<void> waitForRefresh(Dio client, Map command) async {
  final id = command['id'] as int;
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  while (command['status'] != 'completed') {
    if (!{'queued', 'started'}.contains(command['status'])) {
      throw StateError(command['message'] ?? 'Refresh status: ${command['status']}');
    }
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for refresh');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    command = (await client.get<Map>('command/$id')).data!;
  }
}
