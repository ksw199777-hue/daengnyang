class ProductModel {
  final String id;
  final String name;
  final String category; // food/snack/supplement/health
  final String description;
  final List<String> pros;
  final List<String> warnings;
  final List<String> tags; // 관절케어/다이어트/노령견 등
  final String coupangUrl;
  final String targetSpecies; // dog/cat/both
  final bool isAffiliate;
  final String? affiliateUrl;
  final bool isFeatured;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.pros = const [],
    this.warnings = const [],
    this.tags = const [],
    required this.coupangUrl,
    this.targetSpecies = 'both',
    this.isAffiliate = false,
    this.affiliateUrl,
    this.isFeatured = false,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      pros: List<String>.from(map['pros'] ?? []),
      warnings: List<String>.from(map['warnings'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      coupangUrl: map['coupangUrl'] ?? '',
      targetSpecies: map['targetSpecies'] ?? 'both',
      isAffiliate: map['isAffiliate'] ?? false,
      affiliateUrl: map['affiliateUrl'],
      isFeatured: map['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'pros': pros,
      'warnings': warnings,
      'tags': tags,
      'coupangUrl': coupangUrl,
      'targetSpecies': targetSpecies,
      'isAffiliate': isAffiliate,
      'affiliateUrl': affiliateUrl,
      'isFeatured': isFeatured,
    };
  }
}