class UpdateChangelogItem {
  final String version;
  final String? date;
  final String changes;

  const UpdateChangelogItem({
    required this.version,
    this.date,
    required this.changes,
  });

  factory UpdateChangelogItem.fromJson(Map<String, dynamic> json) {
    return UpdateChangelogItem(
      version: json['version']?.toString() ?? '',
      date: json['date']?.toString(),
      changes: json['changes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'changes': changes,
      };
}

class AppUpdateModel {
  final String version;
  final String? buildDate;
  final int buildNumber;
  final bool forceUpdate;
  final String? minimumVersion;
  final String updateUrl;
  final String? fileSize;
  final List<UpdateChangelogItem> changelog;
  final String? releaseNotes;
  final bool success;

  const AppUpdateModel({
    required this.version,
    this.buildDate,
    required this.buildNumber,
    this.forceUpdate = false,
    this.minimumVersion,
    required this.updateUrl,
    this.fileSize,
    this.changelog = const [],
    this.releaseNotes,
    this.success = true,
  });

  factory AppUpdateModel.fromJson(Map<String, dynamic> json) {
    final rawData = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final changelogList = (rawData['changelog'] as List<dynamic>?)
            ?.map((e) => UpdateChangelogItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    final isRequired = rawData['required'] == true ||
        rawData['force_update'] == true ||
        rawData['is_required'] == true ||
        rawData['force'] == true;

    final downloadUrl = rawData['download_url']?.toString() ??
        rawData['update_url']?.toString() ??
        rawData['url']?.toString() ??
        '';

    return AppUpdateModel(
      version: rawData['version']?.toString() ?? '1.0.0',
      buildDate: rawData['build_date']?.toString() ?? rawData['date']?.toString(),
      buildNumber: (rawData['build_number'] is num)
          ? (rawData['build_number'] as num).toInt()
          : int.tryParse(rawData['build_number']?.toString() ?? '') ?? 0,
      forceUpdate: isRequired,
      minimumVersion: rawData['minimum_version']?.toString(),
      updateUrl: downloadUrl,
      fileSize: rawData['file_size']?.toString() ?? rawData['size']?.toString(),
      changelog: changelogList,
      releaseNotes: rawData['release_notes']?.toString(),
      success: rawData['success'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'build_date': buildDate,
        'build_number': buildNumber,
        'force_update': forceUpdate,
        'minimum_version': minimumVersion,
        'update_url': updateUrl,
        'download_url': updateUrl,
        'file_size': fileSize,
        'changelog': changelog.map((e) => e.toJson()).toList(),
        'release_notes': releaseNotes,
        'required': forceUpdate,
        'success': success,
      };
}
