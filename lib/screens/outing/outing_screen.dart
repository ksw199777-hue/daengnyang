import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final List<String> _categories = [
    '동물병원',
    '미용한댕',
    '미용하냥',
    '펫호텔',
    '애견카페',
    '공원',
  ];

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
      'https://map.kakao.com/link/map/${Uri.encodeComponent(place['place_name'])},$lat,$lng',
    );
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  place['place_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (place['road_address_name'] != null &&
                  place['road_address_name'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Text(
                    place['road_address_name'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMid,
                    ),
                  ),
                ),
              if (place['phone'] != null && place['phone'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Text(
                    place['phone'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMid,
                    ),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                ),
                title: const Text(
                  '정보 보기',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openPlaceInfo(place);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.map_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  '지도로 보기',
                  style: TextStyle(color: AppColors.textDark),
                ),
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
        children: [const _ShoppingTab(), _buildPlacesTab()],
      ),
    );
  }

  Widget _buildPlacesTab() {
    return Column(
      children: [
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
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textMid,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _isLoadingPlaces
              ? const Center(child: CircularProgressIndicator())
              : _places.isEmpty
              ? const Center(
                  child: Text(
                    '주변 장소를 찾을 수 없어요',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 4,
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
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 0.5,
                          ),
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
                              child: const Icon(
                                Icons.place_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place['place_name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    place['road_address_name'] ??
                                        place['address_name'] ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMid,
                                    ),
                                  ),
                                  if (place['distance'] != null &&
                                      place['distance'].toString().isNotEmpty)
                                    Text(
                                      _formatDistance(
                                        int.tryParse(
                                              place['distance'].toString(),
                                            ) ??
                                            0,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textLight,
                              size: 18,
                            ),
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

// 쇼핑 탭
class _ShoppingTab extends StatefulWidget {
  const _ShoppingTab();

  @override
  State<_ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<_ShoppingTab> {
  String _petTypeFilter = 'dog';
  String _selectedCategory = '사료';
  String? _selectedSubCategory;
  List<Map<String, dynamic>> _pets = [];

  final Map<String, Map<String, List<String>>> _subCategories = {
    'dog': {
      '사료': ['전체', '퍼피', '어덜트', '시니어', '처방식', '습식', '건식'],
      '간식': ['전체', '껌/뼈간식', '동결건조', '저키/육포', '캔', '파우치', '소시지', '덴탈간식', '우유'],
      '용품': [
        '전체',
        '배변용품',
        '위생용품',
        '구강용품',
        '미용&관리',
        '목욕용품',
        '장난감&노즈워크',
        '훈련용품',
        '산책용품',
        '하우스&방석',
        '이동장&유모차',
        '의류&패션',
        '급식기&급수기',
        '기저귀',
        '넥카라',
      ],
      '영양제': ['전체', '관절', '피부/모질', '장/소화', '눈/귀', '면역', '종합'],
    },
    'cat': {
      '사료': ['전체', '키튼', '어덜트', '시니어', '처방식', '습식', '건식'],
      '간식': [
        '전체',
        '파우치',
        '캔',
        '동결건조',
        '저키/스낵',
        '소시지',
        '캣닢&캣그라스',
        '덴탈간식',
        '파우더',
        '우유',
      ],
      '용품': [
        '전체',
        '모래&화장실',
        '장난감&사냥놀이',
        '스크래처',
        '구강용품',
        '미용&관리',
        '목욕용품',
        '위생용품',
        '의류',
        '하네스',
        '이동장&유모차',
        '급식기&급수기',
        '하우스&방석',
        '캣타워&캣휠',
        '넥카라',
        '울타리&안전문',
        '먹이퍼즐',
      ],
      '영양제': ['전체', '관절', '피부/모질', '장/소화', '눈/귀', '면역', '헤어볼'],
    },
  };

  final List<String> _mainCategories = ['사료', '간식', '용품', '영양제'];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();
    if (mounted) {
      setState(() {
        _pets = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        // 반려동물 종에 따라 기본 필터 설정
        if (_pets.isNotEmpty) {
          _petTypeFilter = _pets.first['species'] == 'cat' ? 'cat' : 'dog';
        }
      });
    }
  }

  List<String> get _currentSubCategories =>
      (_subCategories[_petTypeFilter] ??
          _subCategories['dog']!)[_selectedCategory] ??
      [];

  Query _buildQuery({String? category, String? subCategory}) {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('petType', whereIn: [_petTypeFilter, 'all']);
    if (category != null) query = query.where('category', isEqualTo: category);
    if (subCategory != null)
      query = query.where('subCategory', isEqualTo: subCategory);
    return query;
  }

  void _showCategoryPicker() {
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ..._mainCategories.map(
                (cat) => ListTile(
                  title: Text(
                    cat,
                    style: TextStyle(
                      color: _selectedCategory == cat
                          ? AppColors.primary
                          : AppColors.textDark,
                      fontWeight: _selectedCategory == cat
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _selectedCategory == cat
                      ? const Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedSubCategory = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubCategoryPicker() {
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _currentSubCategories
                        .map(
                          (sub) => ListTile(
                            title: Text(
                              sub,
                              style: TextStyle(
                                color:
                                    (sub == '전체' &&
                                            _selectedSubCategory == null) ||
                                        _selectedSubCategory == sub
                                    ? AppColors.primary
                                    : AppColors.textDark,
                                fontWeight:
                                    (sub == '전체' &&
                                            _selectedSubCategory == null) ||
                                        _selectedSubCategory == sub
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing:
                                (sub == '전체' && _selectedSubCategory == null) ||
                                    _selectedSubCategory == sub
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 18,
                                  )
                                : null,
                            onTap: () {
                              setState(
                                () => _selectedSubCategory = sub == '전체'
                                    ? null
                                    : sub,
                              );
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // 강아지/고양이 필터 (중앙 정렬)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPetBtn('dog', '강아지'),
              const SizedBox(width: 8),
              _buildPetBtn('cat', '고양이'),
            ],
          ),
          const SizedBox(height: 12),

          // 드롭다운 필터
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showCategoryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.textMid,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _showSubCategoryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSubCategory != null
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedSubCategory != null
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedSubCategory ?? '전체',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedSubCategory != null
                                  ? AppColors.primary
                                  : AppColors.textMid,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: _selectedSubCategory != null
                                ? AppColors.primary
                                : AppColors.textMid,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 상품 섹션 타이틀
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_selectedCategory ${_selectedSubCategory ?? '전체'}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 8),

          FutureBuilder<QuerySnapshot>(
            future: _buildQuery(
              category: _selectedCategory,
              subCategory: _selectedSubCategory,
            ).limit(4).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '등록된 상품이 없어요',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                );
              }
              final products = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();
              return Column(
                children: products
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ProductCard(product: p),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),

          // 전체 상품 보기 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ProductListScreen(
                    petType: _petTypeFilter,
                    category: _selectedCategory,
                    subCategory: _selectedSubCategory,
                    subCategories:
                        _subCategories[_petTypeFilter] ??
                        _subCategories['dog']!,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_selectedCategory ${_selectedSubCategory ?? ''} 전체 상품 보기',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMid,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.textMid,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 맞춤 추천
          if (_pets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    '맞춤 추천',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('products')
                  .where('petType', whereIn: [_petTypeFilter, 'all'])
                  .limit(4)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '추천 상품이 없어요',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final products = snapshot.data!.docs
                    .map(
                      (doc) => {
                        'id': doc.id,
                        ...doc.data() as Map<String, dynamic>,
                      },
                    )
                    .toList();
                return Column(
                  children: products
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _ProductCard(product: p),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPetBtn(String type, String label) {
    final isSelected = _petTypeFilter == type;
    return GestureDetector(
      onTap: () => setState(() {
        _petTypeFilter = type;
        _selectedSubCategory = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textMid,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// 전체 상품 목록 화면
class _ProductListScreen extends StatefulWidget {
  final String petType;
  final String category;
  final String? subCategory;
  final Map<String, List<String>> subCategories;

  const _ProductListScreen({
    required this.petType,
    required this.category,
    required this.subCategories,
    this.subCategory,
  });

  @override
  State<_ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<_ProductListScreen> {
  late String _petType;
  late String _category;
  late String? _subCategory;
  late Map<String, List<String>> _subCategories;

  @override
  void initState() {
    super.initState();
    _petType = widget.petType;
    _category = widget.category;
    _subCategory = widget.subCategory;
    _subCategories = widget.subCategories;
  }

  Stream<QuerySnapshot> _getStream() {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('petType', whereIn: [_petType, 'all'])
        .where('category', isEqualTo: _category);
    if (_subCategory != null) {
      query = query.where('subCategory', isEqualTo: _subCategory);
    }
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('$_category ${_subCategory ?? '전체'}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // 강아지/고양이 필터
                GestureDetector(
                  onTap: () => setState(() => _petType = 'dog'),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _petType == 'dog'
                          ? AppColors.primary
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _petType == 'dog'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '강아지',
                      style: TextStyle(
                        fontSize: 13,
                        color: _petType == 'dog'
                            ? Colors.white
                            : AppColors.textMid,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _petType = 'cat'),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _petType == 'cat'
                          ? AppColors.primary
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _petType == 'cat'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '고양이',
                      style: TextStyle(
                        fontSize: 13,
                        color: _petType == 'cat'
                            ? Colors.white
                            : AppColors.textMid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 세부카테고리
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: (_subCategories[_category] ?? []).length,
              itemBuilder: (context, index) {
                final sub = (_subCategories[_category] ?? [])[index];
                final isSelected =
                    (sub == '전체' && _subCategory == null) ||
                    _subCategory == sub;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _subCategory = sub == '전체' ? null : sub),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMid,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 상품이 없어요',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }
                final products = snapshot.data!.docs
                    .map(
                      (doc) => {
                        'id': doc.id,
                        ...doc.data() as Map<String, dynamic>,
                      },
                    )
                    .toList();
                return GridView.builder(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _ProductGridCard(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final url = product['coupangUrl'];
        if (url != null && (url as String).isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: product['imageUrl'] != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        product['imageUrl'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: AppColors.cardBackground,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Container(
                        color: AppColors.cardBackground,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textLight,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (product['description'] != null &&
                      (product['description'] as String).isNotEmpty)
                    Text(
                      product['description'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMid,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () async {
                        final url = product['coupangUrl'];
                        if (url != null && (url as String).isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('구매하기', style: TextStyle(fontSize: 12)),
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
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product['imageUrl'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                product['imageUrl'],
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 180,
                  color: AppColors.cardBackground,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.textLight,
                    size: 40,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product['category'] ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (product['subCategory'] != null &&
                        (product['subCategory'] as String).isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          product['subCategory'],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMid,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        product['petType'] == 'all'
                            ? '전체'
                            : product['petType'] == 'dog'
                            ? '강아지'
                            : '고양이',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMid,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                if (product['description'] != null &&
                    (product['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    product['description'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (product['tags'] != null &&
                    (product['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (product['tags'] as List)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMid,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = product['coupangUrl'];
                      if (url != null && (url as String).isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                    label: const Text('쿠팡에서 구매하기'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
