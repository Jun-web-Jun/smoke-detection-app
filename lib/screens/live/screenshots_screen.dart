import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// 스크린샷 갤러리 화면
class ScreenshotsScreen extends StatefulWidget {
  const ScreenshotsScreen({super.key});

  @override
  State<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends State<ScreenshotsScreen> {
  List<Map<String, dynamic>> _screenshots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScreenshots();
  }

  Future<void> _loadScreenshots() async {
    setState(() => _isLoading = true);
    try {
      final screenshots = await ApiService.fetchScreenshots();
      if (mounted) {
        setState(() {
          _screenshots = screenshots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스크린샷 로딩 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('스크린샷 갤러리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScreenshots,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyan),
            )
          : _screenshots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 80,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '저장된 스크린샷이 없습니다',
                        style: TextStyle(
                          color: Colors.grey.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _screenshots.length,
                  itemBuilder: (context, index) {
                    final screenshot = _screenshots[index];
                    final imageUrl = ApiService.getScreenshotUrl(
                      screenshot['filename'] as String,
                    );

                    return GestureDetector(
                      onTap: () {
                        _showFullImage(context, imageUrl, screenshot);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.cyan.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.withOpacity(0.2),
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.cyan,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(8),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    screenshot['filename'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(screenshot['created']),
                                    style: TextStyle(
                                      color: Colors.grey.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showFullImage(
    BuildContext context,
    String imageUrl,
    Map<String, dynamic> screenshot,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 800),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1E),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.cyan),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                screenshot['filename'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(screenshot['created']),
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Image
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: Colors.grey.withOpacity(0.2),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 60,
                              ),
                            ),
                          );
                        },
                      ),
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

  String _formatTimestamp(dynamic timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (timestamp as num).toInt() * 1000,
      );
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }
}
