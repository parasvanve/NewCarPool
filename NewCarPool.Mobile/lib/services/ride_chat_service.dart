import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_store.dart';
import '../models/chat_models.dart';

class ChatAttachmentFile {
  const ChatAttachmentFile({
    required this.fileName,
    required this.contentType,
    this.path,
    this.bytes,
    this.sizeBytes,
  });

  final String fileName;
  final String contentType;
  final String? path;
  final Uint8List? bytes;
  final int? sizeBytes;
}

class RideChatService {
  RideChatService(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  HubConnection? _connection;

  Future<List<RideChatMessage>> messages(String rideOfferId) async {
    final response =
        await _apiClient.dio.get('/rides/$rideOfferId/chat/messages');
    final items = response.data as List<dynamic>;
    return items
        .map((e) =>
            RideChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RideChatMessage> send({
    required String rideOfferId,
    required String message,
  }) async {
    final response =
        await _apiClient.dio.post('/rides/$rideOfferId/chat/messages', data: {
      'message': message,
    });
    return RideChatMessage.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideChatMessage> uploadAttachment({
    required String rideOfferId,
    required ChatAttachmentFile file,
    String? caption,
  }) async {
    final uploadPath = '/rides/$rideOfferId/chat/attachments';
    final baseUrl = _apiClient.dio.options.baseUrl.endsWith('/')
        ? _apiClient.dio.options.baseUrl.substring(
            0,
            _apiClient.dio.options.baseUrl.length - 1,
          )
        : _apiClient.dio.options.baseUrl;
    final sizeBytes = file.sizeBytes ?? file.bytes?.lengthInBytes ?? 0;
    debugPrint('Ride chat upload baseUrl=$baseUrl');
    debugPrint('Ride chat upload finalPath=$uploadPath');
    debugPrint('Ride chat upload rideId=$rideOfferId');
    debugPrint('Ride chat upload fileName=${file.fileName}');
    debugPrint('Ride chat upload fileSize=$sizeBytes');

    if (kIsWeb && (file.bytes == null || file.bytes!.isEmpty)) {
      throw ArgumentError('Selected file could not be read in this browser.');
    }

    final multipartFile = !kIsWeb && file.path != null
        ? await MultipartFile.fromFile(
            file.path!,
            filename: file.fileName,
            contentType: DioMediaType.parse(file.contentType),
          )
        : MultipartFile.fromBytes(
            file.bytes ?? Uint8List(0),
            filename: file.fileName,
            contentType: DioMediaType.parse(file.contentType),
          );

    final formData = FormData.fromMap({
      'file': multipartFile,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
    });

    final response = await _apiClient.dio.post(
      uploadPath,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return RideChatMessage.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> connect(void Function(RideChatMessage) onMessage) async {
    if (_connection?.state == HubConnectionState.Connected) return;
    final token = await _tokenStore.accessToken;
    if (token == null) return;
    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/notifications',
          options: HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('ChatMessageReceived', (args) {
      if (args == null || args.isEmpty || args.first is! Map) return;
      onMessage(RideChatMessage.fromJson(
          Map<String, dynamic>.from(args.first as Map)));
    });

    await _connection!.start();
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _connection = null;
  }
}
