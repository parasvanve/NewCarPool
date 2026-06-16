import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_date_formatter.dart';
import '../../models/chat_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ride_chat_provider.dart';
import '../../services/ride_chat_service.dart';

class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.ride});

  final RideOffer ride;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RideChatProvider>();
      provider.load(widget.ride.id).then((_) => _scrollToEnd());
      provider.connectRealtime();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showAttachmentSheet() async {
    final chat = context.read<RideChatProvider>();
    if (chat.isUploading) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCameraImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickGalleryImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCameraImage() async {
    if (kIsWeb) {
      _showError(
        'Camera capture is not supported in this browser. Please upload from device.',
      );
      await _pickGalleryImage();
      return;
    }

    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('Camera permission is required.');
        return;
      }
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (image == null) return;
    final sizeBytes = await image.length();
    await _uploadPickedFile(
      fileName: image.name,
      path: image.path,
      bytes: null,
      sizeBytes: sizeBytes,
      contentType: image.mimeType ?? _contentTypeForFileName(image.name),
    );
  }

  Future<void> _pickGalleryImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = kIsWeb ? await image.readAsBytes() : null;
    final sizeBytes = bytes?.lengthInBytes ?? await image.length();
    await _uploadPickedFile(
      fileName: image.name,
      path: image.path,
      bytes: bytes,
      sizeBytes: sizeBytes,
      contentType: image.mimeType ?? _contentTypeForFileName(image.name),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx'],
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    await _uploadPickedFile(
      fileName: file.name,
      path: file.path,
      bytes: file.bytes,
      sizeBytes: file.size,
      contentType: _contentTypeForFileName(file.name),
    );
  }

  Future<void> _uploadPickedFile({
    required String fileName,
    required String contentType,
    String? path,
    Uint8List? bytes,
    int? sizeBytes,
  }) async {
    try {
      final caption = _ctrl.text.trim();
      final chatProvider = context.read<RideChatProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      await chatProvider.uploadAttachment(
        rideOfferId: widget.ride.id,
        file: ChatAttachmentFile(
          fileName: fileName,
          contentType: contentType,
          path: path,
          bytes: bytes,
          sizeBytes: sizeBytes,
        ),
        caption: caption.isEmpty ? null : caption,
      );
      if (caption.isNotEmpty) _ctrl.clear();
      await notificationProvider.loadUnreadCount();
      _scrollToEnd();
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<RideChatProvider>();
    final me = context.watch<AuthProvider>().session?.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Group Chat')),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the ride chat.'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: chat.messages.length,
                        itemBuilder: (_, i) {
                          final m = chat.messages[i];
                          final mine = me != null && me == m.senderUserId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(maxWidth: 360),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFEDEBFF)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(m.senderName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  _ChatMessageContent(message: m),
                                  const SizedBox(height: 4),
                                  Text(
                                    chatTime(m.createdAtUtc),
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: chat.isUploading ? null : _showAttachmentSheet,
                    icon: chat.isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chat.isUploading
                        ? null
                        : () async {
                            final text = _ctrl.text.trim();
                            if (text.isEmpty) return;
                            _ctrl.clear();
                            final chatProvider =
                                context.read<RideChatProvider>();
                            final notificationProvider =
                                context.read<NotificationProvider>();
                            await chatProvider.send(widget.ride.id, text);
                            await notificationProvider.loadUnreadCount();
                            _scrollToEnd();
                          },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ChatMessageContent extends StatelessWidget {
  const _ChatMessageContent({required this.message});

  final RideChatMessage message;

  @override
  Widget build(BuildContext context) {
    return switch (message.messageType) {
      RideChatMessageType.image => _ImageMessage(message: message),
      RideChatMessageType.file => _FileMessage(message: message),
      RideChatMessageType.text => Text(message.message),
    };
  }
}

class _ImageMessage extends StatelessWidget {
  const _ImageMessage({required this.message});

  final RideChatMessage message;

  @override
  Widget build(BuildContext context) {
    final url = toAbsoluteFileUrl(message.attachmentUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url.isNotEmpty)
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _ImagePreviewScreen(url: url)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 240,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 240,
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        if (message.message.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message.message),
        ],
      ],
    );
  }
}

class _FileMessage extends StatelessWidget {
  const _FileMessage({required this.message});

  final RideChatMessage message;

  @override
  Widget build(BuildContext context) {
    final url = toAbsoluteFileUrl(message.attachmentUrl);
    final name = message.attachmentFileName ?? 'Attachment';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (message.attachmentSizeBytes != null)
                    Text(
                      _formatBytes(message.attachmentSizeBytes!),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open',
              onPressed: url.isEmpty
                  ? null
                  : () => launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        if (message.message.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message.message),
        ],
      ],
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  const _ImagePreviewScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _contentTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  return 'application/octet-stream';
}

String toAbsoluteFileUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
      : AppConfig.apiBaseUrl;
  final path = url.startsWith('/') ? url : '/$url';
  return '$base$path';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
