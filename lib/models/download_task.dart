
enum TaskState { queued, running, paused, done, failed }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.label,
    required this.ext,
    required this.audioOnly,
    required this.path,
    this.received = 0,
    this.total = 0,
    this.state = TaskState.queued,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String url;
  final String label; // مثل 720p أو 128k
  final String ext;
  final bool audioOnly;
  final String path;
  final DateTime createdAt;

  int received;
  int total;
  TaskState state;
  String? error;

  /// قيمة لحظية غير محفوظة.
  double speedBps = 0;

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'label': label,
        'ext': ext,
        'audioOnly': audioOnly,
        'path': path,
        'received': received,
        'total': total,
        'state': state.name,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        label: j['label'] as String,
        ext: j['ext'] as String,
        audioOnly: j['audioOnly'] as bool,
        path: j['path'] as String,
        received: (j['received'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        state: TaskState.values.firstWhere(
          (s) => s.name == j['state'],
          orElse: () => TaskState.paused,
        ),
        error: j['error'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}
