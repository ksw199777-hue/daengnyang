import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:daengnyang/core/colors.dart';

class OutingScreen extends StatefulWidget {
  const OutingScreen({super.key});

  @override
  State<OutingScreen> createState() => _OutingScreenState();
}

class _OutingScreenState extends State<OutingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _places = [];
  bool _isLoadingPlaces = false;
  String _selectedCategory = '동물병원';

  final String _kakaoRestApiKey = '678173452b9a4d492a37742749479ed4';
  final List<String> _categories = ['동물병원', '미용한댕', '미용하냥', '펫호텔', '애견카페', '공원'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNearbyPlaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() => _isLoadingPlaces = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingPlaces = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      String searchQuery = _selectedCategory;
      if (_selectedCategory == '미용한댕') searchQuery = '강아지미용';
      if (_selectedCategory == '미용하냥') searchQuery = '고양이미용';

      final response = await http.get(
        Uri.parse(
          'https://dapi.kakao.com/v2/local/search/keyword.json'
          '?query=$searchQuery'
          '&x=${position.longitude}'
          '&y=${position.latitude}'
          '&radius=5000'
          '&size=15',
        ),
        headers: {'Authorization': 'KakaoAK $_kakaoRestApiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;
        setState(() {
          _places = documents.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      print('장소 로딩 에러: $e');
    } finally {
      setState(() => _isLoadingPlaces = false);
    }
  }

  Future<void> _openKakaoMap(Map<String, dynamic> place) async {
    final lat = place['y'];
    final lng = place['x'];
    final kakaoMapUrl = Uri.parse('kakaomap://look?p=$lat,$lng');
    final kakaoMapWebUrl = Uri.parse(
        'https://map.kakao.com/link/map/${Uri.encodeComponent(place['place_name'])},$lat,$lng');

    if (await canLaunchUrl(kakaoMapUrl)) {
      await launchUrl(kakaoMapUrl);
    } else {
      await launchUrl(kakaoMapWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPlaceInfo(Map<String, dynamic> place) async {
    final placeUrl = place['place_url'];
    if (placeUrl != null && placeUrl.isNotEmpty) {
      final uri = Uri.parse(placeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showPlaceOptions(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  place['place_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (place['road_address_name'] != null && place['road_address_name'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    place['road_address_name'],
                    style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                ),
              if (place['phone'] != null && place['phone'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    place['phone'],
                    style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.primary),
                title: const Text('정보 보기', style: TextStyle(color: AppColors.textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _openPlaceInfo(place);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                title: const Text('지도로 보기', style: TextStyle(color: AppColors.textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _openKakaoMap(place);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('나들이'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '쇼핑'),
            Tab(text: '장소'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShoppingTab(),
          _buildPlacesTab(),
        ],
      ),
    );
  }

  Widget _buildShoppingTab() {
    return const Center(
      child: Text('쇼핑 준비 중',
          style: TextStyle(color: AppColors.textLight, fontSize: 14)),
    );
  }

  Widget _buildPlacesTab() {
    return Column(
      children: [
        // 카테고리 두 줄 그리드
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = category);
                  _loadNearbyPlaces();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textMid,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 장소 목록
        Expanded(
          child: _isLoadingPlaces
              ? const Center(child: CircularProgressIndicator())
              : _places.isEmpty
                  ? const Center(
                      child: Text('주변 장소를 찾을 수 없어요',
                          style: TextStyle(color: AppColors.textLight)))
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16, right: 16, top: 4,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      itemCount: _places.length,
                      itemBuilder: (context, index) {
                        final place = _places[index];
                        return GestureDetector(
                          onTap: () => _showPlaceOptions(place),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.place_outlined,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(place['place_name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textDark,
                                          )),
                                      const SizedBox(height: 2),
                                      Text(
                                        place['road_address_name'] ?? place['address_name'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                                      ),
                                      if (place['distance'] != null && place['distance'].toString().isNotEmpty)
                                        Text(
                                          _formatDistance(int.tryParse(place['distance'].toString()) ?? 0),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.textLight, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}