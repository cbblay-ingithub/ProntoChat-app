import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Modal bottom sheet or dialog to preview an image before sending it in chat,
/// with an optional caption text input and progress indicator.
class ImagePreviewSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;
  final Color primaryColor;
  final Future<void> Function(Uint8List bytes, String fileName, String caption) onSend;

  const ImagePreviewSheet({
    super.key,
    required this.imageBytes,
    required this.fileName,
    required this.primaryColor,
    required this.onSend,
  });

  static Future<void> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
    required Color primaryColor,
    required Future<void> Function(Uint8List bytes, String fileName, String caption) onSend,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImagePreviewSheet(
        imageBytes: imageBytes,
        fileName: fileName,
        primaryColor: primaryColor,
        onSend: onSend,
      ),
    );
  }

  @override
  State<ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<ImagePreviewSheet> {
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSend(
        widget.imageBytes,
        widget.fileName,
        _captionController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color.fromRGBO(24, 23, 26, 1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: bottomInset + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Send Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Image Preview Container
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                  ),
                  color: Colors.black38,
                  child: Center(
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Error display
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Caption input field
              Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(38, 37, 41, 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _captionController,
                  enabled: !_isUploading,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Add a caption... (optional)',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions: Send button or Progress
              if (_isUploading)
                Column(
                  children: [
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Optimizing and uploading image...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _handleSend,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
