class PostModel {
  final String id;
  final String userId;
  final String category; // community/trade
  final String title;
  final String content;
  final List<String> images;
  final int? price; // 중고거래용
  final bool isBlacklisted;
  final int reportCount;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.content,
    this.images = const [],
    this.price,
    this.isBlacklisted = false,
    this.reportCount = 0,
    required this.createdAt,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      category: map['category'] ?? 'community',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      price: map['price'],
      isBlacklisted: map['isBlacklisted'] ?? false,
      reportCount: map['reportCount'] ?? 0,
      createdAt: map['createdAt'].toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category,
      'title': title,
      'content': content,
      'images': images,
      'price': price,
      'isBlacklisted': isBlacklisted,
      'reportCount': reportCount,
      'createdAt': createdAt,
    };
  }
}