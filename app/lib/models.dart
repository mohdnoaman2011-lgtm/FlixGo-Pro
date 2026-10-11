class MediaInfo {
  MediaInfo({
    required this.url,
    required this.title,
    required this.uploader,
    required this.platform,
    this.thumbnail,
    this.duration,
    this.heights = const [],
  });

  final String url, title, uploader, platform;
  final String? thumbnail;
  final int? duration;
  final List<int> heights;

  factory MediaInfo.fromJson(Map<String, dynamic> j) => MediaInfo(
        url: j['url'] as String,
        title: (j['title'] ?? '') as String,
        uploader: (j['uploader'] ?? '') as String,
        platform: (j['platform'] ?? '') as String,
        thumbnail: j['thumbnail'] as String?,
        duration: (j['duration'] as num?)?.toInt(),
        heights: [
          for (final h in (j['heights'] as List? ?? const [])) (h as num).toInt()
        ],
      );

  String get durationText {
    final d = duration;
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d ~/ 3600, m = (d % 3600) ~/ 60, s = d % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}

class JobStatus {
  JobStatus({
    required this.status,
    this.progress = 0,
    this.speed,
    this.eta,
    this.filename,
    this.error,
  });

  final String status;
  final double progress;
  final double? speed;
  final int? eta;
  final String? filename, error;

  factory JobStatus.fromJson(Map<String, dynamic> j) => JobStatus(
        status: j['status'] as String,
        progress: (j['progress'] as num? ?? 0).toDouble(),
        speed: (j['speed'] as num?)?.toDouble(),
        eta: (j['eta'] as num?)?.toInt(),
        filename: j['filename'] as String?,
        error: j['error'] as String?,
      );
}

enum DlStatus { queued, downloading, processing, saving, completed, failed, canceled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    this.thumbnail,
    required this.kind,
    required this.quality,
    required this.format,
  });

  final String id, url, title, kind, format; // id محلي (غير id المهمة على الخادم)
  final String? thumbnail;
  final int quality;

  DlStatus status = DlStatus.queued;
  double progress = 0;
  double? speed;
  int? eta;
  String? localPath, error, jobId;
  bool started = false; // هل أُرسلت للخادم؟

  bool get isActive =>
      status == DlStatus.queued ||
      status == DlStatus.downloading ||
      status == DlStatus.processing ||
      status == DlStatus.saving;

  bool get canCancel =>
      status == DlStatus.queued ||
      status == DlStatus.downloading ||
      status == DlStatus.processing;

  /// null = شريط تقدم غير محدد
  double? get progressValue =>
      (status == DlStatus.downloading || status == DlStatus.saving)
          ? progress / 100
          : null;

  String get qualityLabel => kind == 'video' ? '${quality}p' : '${quality}kbps';

  String get statusLabel {
    switch (status) {
      case DlStatus.queued:
        return 'في الانتظار';
      case DlStatus.downloading:
        final sp = speed == null
            ? ''
            : ' · ${(speed! / 1048576).toStringAsFixed(1)} م.ب/ث';
        return 'جارٍ التحميل ${progress.toStringAsFixed(0)}%$sp';
      case DlStatus.processing:
        return 'جارٍ المعالجة (دمج/تحويل)';
      case DlStatus.saving:
        return 'جارٍ الحفظ على الجهاز ${progress.toStringAsFixed(0)}%';
      case DlStatus.completed:
        return 'تم الحفظ';
      case DlStatus.failed:
        return error ?? 'فشل التحميل';
      case DlStatus.canceled:
        return 'أُلغي';
    }
  }
}
