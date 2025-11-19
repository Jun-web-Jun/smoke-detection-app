import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http; // 🚨 http 패키지 추가
import 'dart:async';
import 'dart:typed_data';

import '../../services/api_service.dart';
import 'screenshots_screen.dart';
import '../../providers/settings_provider.dart';

/// 모바일용 라이브 스트림 화면
class LiveScreenSimple extends ConsumerStatefulWidget {
  const LiveScreenSimple({super.key});

  @override
  ConsumerState<LiveScreenSimple> createState() => _LiveScreenSimpleState();
}

class _LiveScreenSimpleState extends ConsumerState<LiveScreenSimple> {
  // 🚨 MJPEG 수동 파싱을 위한 상태 변수 추가
  Uint8List? _latestFrame;
  StreamSubscription? _streamSubscription;
  bool _isStreaming = false; // 스트림이 연결되어 프레임을 받는 중인지
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _startStreaming(); // 화면이 처음 로드될 때 스트림 시작
  }

  @override
  void dispose() {
    _streamSubscription?.cancel(); // 위젯이 파괴될 때 스트림 정리
    super.dispose();
  }

  // MJPEG 스트림을 직접 파싱하고 프레임을 업데이트하는 핵심 로직
  void _startStreaming() async {
    final url = Uri.parse(ref.read(settingsProvider).streamUrl);

    _streamSubscription?.cancel();
    setState(() {
      _isStreaming = false;
      _latestFrame = null;
    });

    try {
      final request = http.Request('GET', url);
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      // 🚨 서버(real_server.py)와 정확히 일치하는 바운더리
      const boundary = 'frame'; 
      final boundaryBytes = Uint8List.fromList('--$boundary\r\n'.codeUnits);
      final separator = Uint8List.fromList('\r\n\r\n'.codeUnits);
      
      List<int> frameData = [];
      int start = 0;

      _streamSubscription = response.stream.listen(
        (data) {
          if (frameData.length > 1024 * 1024 * 5) { // 5MB 초과 시 메모리 보호
             frameData.clear();
             start = 0;
             return;
          }
          frameData.addAll(data);
          
          while (true) {
            // 바운더리 시작 위치 찾기
            int boundaryIndex = _indexOfBytes(frameData, boundaryBytes, start);
            if (boundaryIndex == -1) break; 
            
            // 헤더와 이미지 데이터 경계 찾기 (\r\n\r\n)
            int separatorIndex = _indexOfBytes(frameData, separator, boundaryIndex);
            if (separatorIndex == -1) break;

            int imageStartIndex = separatorIndex + separator.length;
            
            // 다음 바운더리 찾기 (이미지 데이터의 끝)
            int nextBoundaryIndex = _indexOfBytes(frameData, boundaryBytes, imageStartIndex);
            
            if (nextBoundaryIndex == -1) break;

            // 이미지 데이터 추출 및 화면 업데이트
            Uint8List imageBytes = Uint8List.fromList(frameData.sublist(imageStartIndex, nextBoundaryIndex));

            if (mounted) {
              setState(() {
                _latestFrame = imageBytes;
                _isStreaming = true;
              });
            }
            
            // 처리된 데이터 제거 및 다음 검색 시작 위치 업데이트
            frameData.removeRange(0, nextBoundaryIndex);
            start = 0; 
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _latestFrame = null;
              _isStreaming = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('스트림 오류 발생: $error'), backgroundColor: Colors.red),
            );
          }
          _streamSubscription?.cancel();
        },
        onDone: () {
          if (mounted) {
            setState(() => _isStreaming = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('스트림 연결이 종료되었습니다.')),
            );
          }
        }
      );

    } catch (e) {
      if (mounted) {
        setState(() => _isStreaming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 시작 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // List<int>에서 특정 바이트 시퀀스를 찾는 헬퍼 함수
  int _indexOfBytes(List<int> source, List<int> search, [int start = 0]) {
    if (search.isEmpty || start < 0) return -1;
    for (int i = start; i <= source.length - search.length; i++) {
      bool found = true;
      for (int j = 0; j < search.length; j++) {
        if (source[i + j] != search[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// 스크린샷 캡처 (데모 모드) - 기존 로직 유지
  Future<void> _captureScreenshot() async {
    // 🚨 실제 캡처 로직이 필요하다면 _latestFrame을 사용해야 합니다.
    if (_latestFrame == null) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('캡처할 프레임이 없습니다.'), backgroundColor: Colors.orange),
         );
      }
      return;
    }
    
    setState(() => _isCapturing = true);
    // ... (기존 캡처 성공/실패 UI 로직은 유지)
    try {
      await Future.delayed(const Duration(milliseconds: 800)); // 시뮬레이션

      if (mounted) {
        final timestamp = DateTime.now();
        final filename = 'capture_${timestamp.millisecondsSinceEpoch}.jpg';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '캡처 완료!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        filename,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '갤러리',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScreenshotsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캡처 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // settingsProvider를 watch해서 설정값을 가져옵니다 (URL은 이제 _startStreaming에서 사용)
    ref.watch(settingsProvider); 

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                  const SizedBox(width: 4),
                  Text(_isStreaming ? 'LIVE' : 'IDLE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('실시간 모니터링'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: '스크린샷 갤러리',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScreenshotsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startStreaming, // 새로고침 버튼을 스트림 재시작으로 연결
          ),
        ],
      ),
      body: Column(
        children: [
          // 카메라 정보 헤더 (동일)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border(
                bottom: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                // ... (카메라 정보 UI 유지)
                // 생략: 코드 길이를 줄이기 위해
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '본관 1층 입구',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            '정상 작동',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🚨 스트림 표시 영역 (MJPEG 수동 파싱 결과 표시)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: _buildStreamWidget(), // 스트림 상태에 따라 위젯 빌드
                ),
              ),
            ),
          ),

          // 컨트롤 패널 (동일)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border(
                top: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _startStreaming, // 새로고침 기능
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          '새로고침',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isCapturing ? null : _captureScreenshot,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyan,
                          side: const BorderSide(color: Colors.cyan),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.cyan,
                                ),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(_isCapturing ? '캡처 중...' : '캡처'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 스트림 상태에 따라 표시할 위젯을 결정하는 헬퍼 함수
  Widget _buildStreamWidget() {
    if (_latestFrame != null) {
      return Image.memory(
        _latestFrame!, // 직접 메모리에 로드된 프레임 표시
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (_isStreaming == false) {
      // 연결 시도 중이 아닐 때 (초기 로딩 또는 실패)
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text('스트림 연결 실패', style: TextStyle(color: Colors.red, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '서버가 켜져있는지, 휴대폰이\n동일한 Wi-Fi에 연결되었는지\n확인해 주세요.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startStreaming,
            child: const Text('재시도'),
          ),
        ],
      );
    }
    
    // 로딩 중일 때 (스트림 연결 시도 중)
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.cyan),
        SizedBox(height: 16),
        Text(
          '스트림 연결 중...',
          style: TextStyle(color: Colors.cyan),
        ),
      ],
    );
  }
}