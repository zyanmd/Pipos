import '../../../../core/config/api_config.dart';

class AvatarDecorationModel {
  final int id;
  final String code;
  final String name;
  final String category;
  final String imageUrl;
  final String? thumbnailUrl;
  final bool isPremium;
  final bool isActive;
  final int sortOrder;
  final bool isOwned;
  final bool localAvailable;

  const AvatarDecorationModel({
    required this.id,
    required this.code,
    required this.name,
    this.category = 'general',
    required this.imageUrl,
    this.thumbnailUrl,
    this.isPremium = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.isOwned = false,
    this.localAvailable = false,
  });

  String get fullImageUrl {
    var cleanUrl = imageUrl;
    if (cleanUrl.toLowerCase().endsWith('.webp')) {
      cleanUrl = '${cleanUrl.substring(0, cleanUrl.length - 5)}.png';
    }
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }
    if (cleanUrl.isEmpty && code.isNotEmpty) {
      return '${ApiConfig.baseUrl}/api/avatar-decorations/image/$code.png';
    }
    final clean = cleanUrl.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  factory AvatarDecorationModel.fromJson(Map<String, dynamic> j) {
    final codeStr = j['code']?.toString() ?? '';
    String nameStr = j['name']?.toString() ?? '';
    if (nameStr.isEmpty && codeStr.isNotEmpty) {
      nameStr = codeStr
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    var imgStr = j['image_url']?.toString() ?? '';
    if (imgStr.toLowerCase().endsWith('.webp')) {
      imgStr = '${imgStr.substring(0, imgStr.length - 5)}.png';
    }
    if (imgStr.isEmpty && codeStr.isNotEmpty) {
      imgStr = '${ApiConfig.baseUrl}/api/avatar-decorations/image/$codeStr.png';
    }

    var thumbStr = j['thumbnail_url']?.toString() ?? imgStr;
    if (thumbStr.toLowerCase().endsWith('.webp')) {
      thumbStr = '${thumbStr.substring(0, thumbStr.length - 5)}.png';
    }

    return AvatarDecorationModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      code: codeStr,
      name: nameStr,
      category: j['category']?.toString() ?? 'general',
      imageUrl: imgStr,
      thumbnailUrl: thumbStr,
      isPremium: j['is_premium'] == true || j['is_premium'] == 1,
      isActive: j['is_active'] != false && j['is_active'] != 0,
      sortOrder: j['sort_order'] is int ? j['sort_order'] as int : int.tryParse(j['sort_order']?.toString() ?? '0') ?? 0,
      isOwned: j['is_owned'] == true || j['is_owned'] == 1,
      localAvailable: j['local_available'] == true || j['local_available'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'category': category,
    'image_url': imageUrl,
    'thumbnail_url': thumbnailUrl,
    'is_premium': isPremium,
    'is_active': isActive,
    'sort_order': sortOrder,
    'is_owned': isOwned,
    'local_available': localAvailable,
  };
}

class UserActiveDecorationModel {
  final int id;
  final String code;
  final String name;
  final String imageUrl;
  final double scale;
  final int offsetX;
  final int offsetY;

  const UserActiveDecorationModel({
    required this.id,
    required this.code,
    required this.name,
    required this.imageUrl,
    this.scale = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  String get fullImageUrl {
    var cleanUrl = imageUrl;
    if (cleanUrl.toLowerCase().endsWith('.webp')) {
      cleanUrl = '${cleanUrl.substring(0, cleanUrl.length - 5)}.png';
    }
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }
    if (cleanUrl.isEmpty && code.isNotEmpty) {
      return '${ApiConfig.baseUrl}/api/avatar-decorations/image/$code.png';
    }
    final clean = cleanUrl.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/$clean';
  }

  factory UserActiveDecorationModel.fromJson(Map<String, dynamic> j) {
    String codeStr = j['code']?.toString() ?? '';
    var imgStr = j['image_url']?.toString() ?? '';
    if (imgStr.toLowerCase().endsWith('.webp')) {
      imgStr = '${imgStr.substring(0, imgStr.length - 5)}.png';
    }
    if (codeStr.isEmpty && imgStr.isNotEmpty) {
      final uri = Uri.tryParse(imgStr);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : imgStr.split('/').last;
      codeStr = seg.replaceAll('.png', '').replaceAll('.gif', '').trim();
    }
    String nameStr = j['name']?.toString() ?? '';
    if (nameStr.isEmpty && codeStr.isNotEmpty) {
      nameStr = codeStr
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    if (imgStr.isEmpty && codeStr.isNotEmpty) {
      imgStr = '${ApiConfig.baseUrl}/api/avatar-decorations/image/$codeStr.png';
    }

    return UserActiveDecorationModel(
      id: j['id'] is int ? j['id'] as int : int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      code: codeStr,
      name: nameStr,
      imageUrl: imgStr,
      scale: (j['scale'] is num) ? (j['scale'] as num).toDouble() : (double.tryParse(j['scale']?.toString() ?? '1.0') ?? 1.0),
      offsetX: j['offset_x'] is int ? j['offset_x'] as int : int.tryParse(j['offset_x']?.toString() ?? '0') ?? 0,
      offsetY: j['offset_y'] is int ? j['offset_y'] as int : int.tryParse(j['offset_y']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'image_url': imageUrl,
    'scale': scale,
    'offset_x': offsetX,
    'offset_y': offsetY,
  };
}

class AvatarDecorationCategoryModel {
  final String name;
  final int count;

  const AvatarDecorationCategoryModel({
    required this.name,
    required this.count,
  });

  factory AvatarDecorationCategoryModel.fromJson(Map<String, dynamic> j) {
    return AvatarDecorationCategoryModel(
      name: j['name']?.toString() ?? '',
      count: j['count'] is int ? j['count'] as int : int.tryParse(j['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class AvatarDecorationStatsModel {
  final int total;
  final Map<String, int> byCategory;
  final int ownedCount;
  final int localPngAvailable;
  final int catalogTotal;

  const AvatarDecorationStatsModel({
    this.total = 0,
    this.byCategory = const {},
    this.ownedCount = 0,
    this.localPngAvailable = 0,
    this.catalogTotal = 0,
  });

  factory AvatarDecorationStatsModel.fromJson(Map<String, dynamic> j) {
    final catMap = <String, int>{};
    if (j['by_category'] is Map) {
      (j['by_category'] as Map).forEach((k, v) {
        catMap[k.toString()] = v is int ? v : (int.tryParse(v.toString()) ?? 0);
      });
    }

    return AvatarDecorationStatsModel(
      total: j['total'] is int ? j['total'] as int : int.tryParse(j['total']?.toString() ?? '0') ?? 0,
      byCategory: catMap,
      ownedCount: j['owned_count'] is int ? j['owned_count'] as int : int.tryParse(j['owned_count']?.toString() ?? '0') ?? 0,
      localPngAvailable: j['local_png_available'] is int ? j['local_png_available'] as int : int.tryParse(j['local_png_available']?.toString() ?? '0') ?? 0,
      catalogTotal: j['catalog_total'] is int ? j['catalog_total'] as int : int.tryParse(j['catalog_total']?.toString() ?? '0') ?? 0,
    );
  }
}

