import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_session.dart';

abstract class AudioUploadService {
  Future<String> upload(File file, {String fileName = 'audio.m4a'});
}

class RemoteAudioUploadService implements AudioUploadService {
  RemoteAudioUploadService(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;

  @override
  Future<String> upload(File file, {String fileName = 'audio.m4a'}) async {
    final user = _session.currentUser;
    if (user == null) {
      throw StateError('需要登录后才能上传音频');
    }

    final uri = _client.baseUri.resolve('uploads/audio');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_client.buildHeaders())
      ..fields['user_id'] = user.id
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('上传失败 (${streamed.statusCode}): $responseBody');
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) {
      final url = decoded['file_url'] as String? ?? decoded['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    throw FormatException('无法解析上传返回结果');
  }
}

class MockAudioUploadService implements AudioUploadService {
  MockAudioUploadService();

  @override
  Future<String> upload(File file, {String fileName = 'audio.m4a'}) async {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return Future.delayed(
      const Duration(milliseconds: 200),
      () => '$base/mock/audio/${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }
}