import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/camera_device.dart';
import '../../providers/cameras_provider.dart';

/// 지도 화면 - 카메라 위치 표시
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // 한밭대학교 N1동(본부관) 중심 좌표
  static const LatLng _schoolCenter = LatLng(36.3500, 127.3017);

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// 카메라 마커 생성
  void _createMarkers() {
    final cameras = ref.read(camerasProvider);

    _markers = cameras.map((camera) {
      return Marker(
        markerId: MarkerId(camera.id),
        position: LatLng(camera.latitude, camera.longitude),
        icon: _getMarkerIcon(camera.status),
        infoWindow: InfoWindow(
          title: camera.name,
          snippet: '${camera.location} - ${_getStatusText(camera.status)}',
          onTap: () => _showCameraDetails(camera),
        ),
        onTap: () => _onMarkerTapped(camera),
      );
    }).toSet();
  }

  /// 카메라 상태에 따른 마커 아이콘
  BitmapDescriptor _getMarkerIcon(CameraStatus status) {
    switch (status) {
      case CameraStatus.online:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case CameraStatus.offline:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case CameraStatus.warning:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// 상태 텍스트
  String _getStatusText(CameraStatus status) {
    switch (status) {
      case CameraStatus.online:
        return '온라인';
      case CameraStatus.offline:
        return '오프라인';
      case CameraStatus.warning:
        return '경고';
    }
  }

  /// 마커 탭 시
  void _onMarkerTapped(CameraDevice camera) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(camera.latitude, camera.longitude),
        18.0,
      ),
    );
  }

  /// 카메라 상세 정보 표시
  void _showCameraDetails(CameraDevice camera) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.videocam,
                  color: _getStatusColor(camera.status),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        camera.location,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(camera.status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(camera.status),
                    style: TextStyle(
                      color: _getStatusColor(camera.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 통계 정보
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.warning_amber,
                    label: '오늘 감지',
                    value: '${camera.todayDetections}건',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.access_time,
                    label: '마지막 감지',
                    value: camera.lastDetection ?? '없음',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/live/${camera.id}');
                    },
                    icon: const Icon(Icons.play_circle),
                    label: const Text('라이브 보기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/events?cameraId=${camera.id}');
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('이력 보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(CameraStatus status) {
    switch (status) {
      case CameraStatus.online:
        return Colors.green;
      case CameraStatus.offline:
        return Colors.red;
      case CameraStatus.warning:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(camerasProvider, (previous, next) {
      setState(() {
        _createMarkers();
      });
    });

    final cameras = ref.watch(camerasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카메라 위치'),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          // 범례 버튼
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLegend(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _schoolCenter,
              zoom: 16.0,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 상단 통계 카드
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: const Color(0xFF1A1A2E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMapStatItem(
                      icon: Icons.videocam,
                      label: '전체 카메라',
                      value: cameras.length.toString(),
                      color: Colors.cyan,
                    ),
                    _buildMapStatItem(
                      icon: Icons.check_circle,
                      label: '온라인',
                      value: cameras.where((c) => c.status == CameraStatus.online).length.toString(),
                      color: Colors.green,
                    ),
                    _buildMapStatItem(
                      icon: Icons.warning_amber,
                      label: '경고',
                      value: cameras.where((c) => c.status == CameraStatus.warning).length.toString(),
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 내 위치로 이동 버튼
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'center_map',
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_schoolCenter, 16.0),
                );
              },
              backgroundColor: const Color(0xFF1A1A2E),
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  /// 범례 표시
  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 상태'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(Colors.green, '온라인', '정상 작동 중'),
            const SizedBox(height: 12),
            _buildLegendItem(Colors.orange, '경고', '최근 감지 발생'),
            const SizedBox(height: 12),
            _buildLegendItem(Colors.red, '오프라인', '연결 끊김'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String description) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
