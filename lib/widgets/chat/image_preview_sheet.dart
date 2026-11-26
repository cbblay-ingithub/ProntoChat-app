import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/pc_tokens.dart';

/// Modal bottom sheet to preview an image before sending it in chat.
class ImagePreviewSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;
  final Color primaryColor;
  final Future<void> Function(Uint8List bytes, String fileName, String caption)
      onSend;

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
    required Future<void> Function(
      Uint8List bytes,
      String fileName,
      String caption,
    ) onSend,
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
    final tokens = context.pcTokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send Photo',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textMuted),
                    onPressed:
                        _isUploading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  color: tokens.surfaceSubtle,
                  child: Center(
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.urgentBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.urgentBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: tokens.urgentText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: tokens.urgentText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _captionController,
                enabled: !_isUploading,
                style: TextStyle(color: tokens.textPrimary, fontSize: 14.5),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Add a caption... (optional)',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceSubtle,
                ),
              ),
              const SizedBox(height: 16),
              if (_isUploading)
                Column(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Optimizing and uploading image...',
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Send',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
