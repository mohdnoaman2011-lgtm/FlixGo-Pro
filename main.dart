// FlixGo — redesigned UI (splash, home, downloads, library, settings)
// with real downloads (dio + path_provider).
// Usage: replace lib/main.dart with this file. Needs: dio, path_provider
// and the INTERNET permission in AndroidManifest.xml.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const FlixGoApp());

class Pal {
  final Color bg, card, ink, mute, line, tint, acc, accInk, pinkBg, pinkInk, ok;
  const Pal({
    required this.bg,
    required this.card,
    required this.ink,
    required this.mute,
    required this.line,
    required this.tint,
    required this.acc,
    required this.accInk,
    required this.pinkBg,
    required this.pinkInk,
    required this.ok,
  });
}

// FlixGo brand identity (from the logo): black, cyan -> blue -> violet -> magenta.
const brandGrad = [
  Color(0xFF19C8FF),
  Color(0xFF2F6BFF),
  Color(0xFF8A2BFF),
  Color(0xFFFF2BD6)
];
// Button gradient: darker stops so white text stays readable.
const btnGrad = [Color(0xFF2F6BFF), Color(0xFF8A2BFF), Color(0xFFD81BBA)];

const lightPal = Pal(
    bg: Color(0xFFF7F5FF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF120F24),
    mute: Color(0xFF5F5A7A),
    line: Color(0xFFE4DEF7),
    tint: Color(0xFFEDE7FF),
    acc: Color(0xFF7B2BFF),
    accInk: Color(0xFF5B21E6),
    pinkBg: Color(0xFFFFE3F6),
    pinkInk: Color(0xFFB8139A),
    ok: Color(0xFF12805C));
const darkPal = Pal(
    bg: Color(0xFF07060F),
    card: Color(0xFF14121F),
    ink: Color(0xFFFFFFFF),
    mute: Color(0xFFA8A3C2),
    line: Color(0xFF2A2540),
    tint: Color(0xFF1F1B35),
    acc: Color(0xFF8A2BFF),
    accInk: Color(0xFF5CD6FF),
    pinkBg: Color(0xFF3A1636),
    pinkInk: Color(0xFFFF6FE0),
    ok: Color(0xFF3DDC97));

const tr = {
  'ar': {
    'tag': 'حمّل ملفاتك الصوتية والمرئية من روابط مباشرة',
    'start': 'ابدأ الآن',
    'h1': 'ماذا تريد أن\nتحمّل اليوم؟',
    'ph': 'الصق رابط الملف المباشر هنا',
    'paste': 'لصق',
    'audio': 'صوت MP3',
    'video': 'فيديو MP4',
    'go': 'ابدأ التحميل',
    'hint': 'يدعم روابط https المباشرة لملفات mp3 و mp4 التي تملكها أو المرخّصة للتحميل.',
    'blocked': 'هذه المنصة غير مدعومة، استخدم رابط ملف مباشر',
    'bad': 'الرابط غير صالح',
    'need': 'الصق رابطاً صالحاً أولاً',
    'recent': 'آخر التحميلات',
    'all': 'عرض الكل',
    'home': 'الرئيسية',
    'dl': 'التحميلات',
    'lib': 'المكتبة',
    'set': 'الإعدادات',
    'active': 'جارٍ التحميل',
    'doneTab': 'مكتملة',
    'noDl': 'لا توجد تحميلات بعد.',
    'started': 'بدأ التحميل',
    'finished': 'اكتمل: ',
    'failed': 'فشل',
    'of': 'من',
    'mb': ' ميجابايت',
    'search': 'ابحث في ملفاتك',
    'fAll': 'الكل',
    'fAudio': 'صوتيات',
    'fVideo': 'فيديو',
    'files': 'ملفات',
    'emptyLib': 'لا توجد ملفات.',
    'delQ': 'حذف هذا الملف؟',
    'del': 'حذف',
    'cancel': 'إلغاء',
    'save': 'التحميل',
    'folder': 'مجلد الحفظ',
    'look': 'المظهر واللغة',
    'light': 'فاتح',
    'dark': 'داكن',
    'lang': 'اللغة',
    'note': 'حمّل فقط المحتوى الذي تملكه أو المتاح برخصة مفتوحة. لا يدعم التطبيق استخراج الفيديو من يوتيوب وغيره من المنصات.',
    'about': 'عن FlixGo',
    'cancelDl': 'إلغاء التحميل',
    'server': 'الخادم',
    'useServer': 'استخدام خادم التحميل (Termux)',
    'srvUrl': 'عنوان الخادم',
    'srvToken': 'الرمز السري (اختياري)',
    'srvTest': 'اختبار الاتصال',
    'srvOk': 'متصل بالخادم',
    'srvFail': 'تعذّر الاتصال',
    'srvTokenBad': 'الرمز السري غير صحيح',
    'srvHint': 'شغّل الخادم في Termux أولاً. على الهاتف نفسه استخدم http://127.0.0.1:8787. وتُحفظ الملفات في مجلد الخادم لا في التطبيق.',
  },
  'en': {
    'tag': 'Download audio and video files from direct links',
    'start': 'Get started',
    'h1': 'What do you want\nto download today?',
    'ph': 'Paste the direct file link here',
    'paste': 'Paste',
    'audio': 'Audio MP3',
    'video': 'Video MP4',
    'go': 'Start download',
    'hint': 'Supports direct https links to mp3 / mp4 files you own or that are licensed for download.',
    'blocked': 'This platform is not supported, use a direct file link',
    'bad': 'Invalid link',
    'need': 'Paste a valid link first',
    'recent': 'Recent downloads',
    'all': 'View all',
    'home': 'Home',
    'dl': 'Downloads',
    'lib': 'Library',
    'set': 'Settings',
    'active': 'In progress',
    'doneTab': 'Completed',
    'noDl': 'No downloads yet.',
    'started': 'Download started',
    'finished': 'Finished: ',
    'failed': 'Failed',
    'of': 'of',
    'mb': ' MB',
    'search': 'Search your files',
    'fAll': 'All',
    'fAudio': 'Audio',
    'fVideo': 'Video',
    'files': 'files',
    'emptyLib': 'No files yet.',
    'delQ': 'Delete this file?',
    'del': 'Delete',
    'cancel': 'Cancel',
    'save': 'Downloading',
    'folder': 'Save folder',
    'look': 'Appearance & language',
    'light': 'Light',
    'dark': 'Dark',
    'lang': 'Language',
    'note': 'Only download content you own or that is openly licensed. The app does not extract video from YouTube or other platforms.',
    'about': 'About FlixGo',
    'cancelDl': 'Cancel download',
    'server': 'Server',
    'useServer': 'Use download server (Termux)',
    'srvUrl': 'Server address',
    'srvToken': 'Secret token (optional)',
    'srvTest': 'Test connection',
    'srvOk': 'Connected to the server',
    'srvFail': 'Could not connect',
    'srvTokenBad': 'Wrong secret token',
    'srvHint': 'Start the server in Termux first. On this phone use http://127.0.0.1:8787. Files are saved in the server folder, not in the app.',
  },
};

const _audioExt = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'opus'};
bool isAudioName(String n) =>
    _audioExt.contains(n.split('.').last.toLowerCase());
String mbOf(int b) => (b / 1048576).toStringAsFixed(1);

class Item {
  final bool audio;
  final String url;
  String name;
  double pr = 0;
  int got = 0, total = 0;
  bool done = false;
  String? path, error;
  final token = CancelToken();
  String? serverId;
  bool remote = false;
  Item(this.audio, this.url, this.name);
}

class LibFile {
  final File? f;
  final String name;
  final int len;
  final bool audio;
  final bool remote;
  LibFile(this.f, this.name, this.len, this.audio, {this.remote = false});
}

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FlixGo',
        debugShowCheckedModeBanner: false,
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool ar = true, dark = true, audio = false, err = false, started = false;
  int tab = 0, dlTab = 0, filter = 0;
  String savePath = '';
  final url = TextEditingController();
  final q = TextEditingController();
  final items = <Item>[];
  var lib = <LibFile>[];
  // Download server (Termux)
  bool useServer = false;
  String serverUrl = 'http://127.0.0.1:8787';
  String serverToken = '';
  String serverMsg = '';
  final urlCtl = TextEditingController(text: 'http://127.0.0.1:8787');
  final tokenCtl = TextEditingController();

  Pal get c => dark ? darkPal : lightPal;
  String t(String k) => tr[ar ? 'ar' : 'en']![k]!;

  bool get valid {
    final u = Uri.tryParse(url.text.trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty;
  }

  bool get blocked {
    final h = (Uri.tryParse(url.text.trim())?.host ?? '').toLowerCase();
    const b = [
      'youtube.com',
      'youtu.be',
      'instagram.com',
      'tiktok.com',
      'twitter.com',
      'x.com',
      'facebook.com',
      'fb.com',
      'fb.watch'
    ];
    return b.any((d) => h == d || h.endsWith('.$d'));
  }

  bool get canStart => valid && !blocked;

  @override
  void initState() {
    super.initState();
    loadPrefs();
    saveDir().then((d) {
      if (mounted) setState(() => savePath = d.path);
    });
    loadLib();
  }

  @override
  void dispose() {
    url.dispose();
    q.dispose();
    urlCtl.dispose();
    tokenCtl.dispose();
    super.dispose();
  }

  void toast(String m) {
    final s = ScaffoldMessenger.of(context);
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(
      content: Text(m,
          style: TextStyle(color: c.bg, fontWeight: FontWeight.w700)),
      backgroundColor: c.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ---------- download server (Termux) ----------

  Dio api() => Dio(BaseOptions(
        baseUrl: serverUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        headers: serverToken.isEmpty ? null : {'X-Token': serverToken},
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 20),
      ));

  String errText(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['code'] == 'blocked') return t('blocked');
      if (d is Map && d['error'] != null) return '${d['error']}';
      return e.message ?? 'network';
    }
    return '$e';
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      useServer = p.getBool('useServer') ?? false;
      serverUrl = p.getString('serverUrl') ?? 'http://127.0.0.1:8787';
      serverToken = p.getString('serverToken') ?? '';
      urlCtl.text = serverUrl;
      tokenCtl.text = serverToken;
    });
    loadLib();
  }

  Future<void> savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('useServer', useServer);
    await p.setString('serverUrl', serverUrl);
    await p.setString('serverToken', serverToken);
  }

  Future<void> testServer() async {
    setState(() => serverMsg = '...');
    try {
      final h = await api().get('/health');
      final auth = h.data is Map && h.data['auth'] == true;
      if (auth) await api().get('/jobs');
      if (mounted) setState(() => serverMsg = t('srvOk'));
    } catch (e) {
      final code = e is DioException ? e.response?.statusCode : null;
      if (mounted) {
        setState(() => serverMsg =
            code == 401 ? t('srvTokenBad') : '${t('srvFail')}: ${errText(e)}');
      }
    }
  }

  Future<void> serverStart(Item it, String link) async {
    it.remote = true;
    try {
      final r = await api().post('/download',
          data: {'url': link, 'kind': it.audio ? 'audio' : 'video'});
      final m = r.data as Map;
      it.serverId = '${m['id']}';
      if (m['name'] != null && mounted) setState(() => it.name = '${m['name']}');
      while (mounted) {
        await Future.delayed(const Duration(milliseconds: 700));
        final j = (await api().get('/jobs/${it.serverId}')).data as Map;
        final st = '${j['status']}';
        if (!mounted) return;
        setState(() {
          it.got = (j['got'] as num?)?.toInt() ?? 0;
          it.total = (j['total'] as num?)?.toInt() ?? 0;
          if (it.total > 0) it.pr = it.got / it.total * 100;
        });
        if (st == 'done') {
          setState(() {
            it.pr = 100;
            it.done = true;
          });
          toast('${t('finished')}${it.name}');
          loadLib();
          return;
        }
        if (st == 'error') {
          setState(() => it.error = '${j['error']}');
          toast(t('failed'));
          return;
        }
        if (st == 'cancelled') {
          setState(() => items.remove(it));
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => it.error = errText(e));
      toast(t('failed'));
    }
  }

  Future<void> cancelItem(Item i) async {
    if (i.serverId != null) {
      try {
        await api().delete('/jobs/${i.serverId}');
      } catch (_) {}
    } else {
      i.token.cancel();
    }
  }

  Future<Directory> saveDir() async {
    final base = (await getExternalStorageDirectory()) ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/FlixGo');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> loadLib() async {
    if (useServer) {
      try {
        final r = await api().get('/files');
        final list = (r.data as Map)['files'] as List;
        if (!mounted) return;
        setState(() {
          lib = [
            for (final x in list)
              LibFile(null, '${x['name']}', (x['size'] as num).toInt(),
                  isAudioName('${x['name']}'),
                  remote: true)
          ];
        });
      } catch (_) {
        if (mounted) setState(() => lib = []);
      }
      return;
    }
    final dir = await saveDir();
    final busy = items
        .where((i) => !i.done && i.error == null)
        .map((i) => i.path)
        .toSet();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => !busy.contains(f.path))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (!mounted) return;
    setState(() {
      lib = [
        for (final f in files)
          LibFile(f, f.path.split('/').last, f.lengthSync(),
              isAudioName(f.path))
      ];
    });
  }

  Future<void> paste() async {
    final d = await Clipboard.getData('text/plain');
    url.text = (d?.text ?? '').trim();
    setState(() {});
  }

  Future<String> uniquePath(String name) async {
    final dir = await saveDir();
    var path = '${dir.path}/$name';
    var n = 1;
    while (await File(path).exists()) {
      final dot = name.lastIndexOf('.');
      path = dot > 0
          ? '${dir.path}/${name.substring(0, dot)}_$n${name.substring(dot)}'
          : '${dir.path}/${name}_$n';
      n++;
    }
    return path;
  }

  Future<void> start() async {
    if (!canStart) {
      setState(() => err = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => err = false);
      });
      toast(blocked ? t('blocked') : t('need'));
      return;
    }
    final link = url.text.trim();
    final segs = Uri.parse(link).pathSegments.where((e) => e.isNotEmpty);
    var name = segs.isEmpty ? '' : segs.last;
    name = name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    if (name.isEmpty) name = 'flixgo_${DateTime.now().millisecondsSinceEpoch}';
    if (!name.contains('.')) name += audio ? '.mp3' : '.mp4';
    final it = Item(audio, link, name);
    setState(() {
      items.insert(0, it);
      url.clear();
    });
    toast(t('started'));
    if (useServer) {
      await serverStart(it, link);
      return;
    }
    try {
      it.path = await uniquePath(name);
      await Dio().download(link, it.path!, cancelToken: it.token,
          onReceiveProgress: (got, total) {
        if (!mounted) return;
        setState(() {
          it.got = got;
          it.total = total;
          if (total > 0) it.pr = got / total * 100;
        });
      });
      if (!mounted) return;
      setState(() {
        it.pr = 100;
        it.done = true;
      });
      toast('${t('finished')}${it.name}');
      loadLib();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        try {
          if (it.path != null) await File(it.path!).delete();
        } catch (_) {}
        if (mounted) setState(() => items.remove(it));
        return;
      }
      if (!mounted) return;
      setState(() =>
          it.error = e is DioException ? (e.message ?? 'network') : '$e');
      toast(t('failed'));
    }
  }

  void setTab(int i) {
    setState(() => tab = i);
    if (i == 2) loadLib();
  }

  // ---------- small building blocks ----------

  Widget tile(bool aud, double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
            color: aud ? c.tint : c.pinkBg,
            borderRadius: BorderRadius.circular(s * .3)),
        child: Icon(aud ? Icons.music_note_rounded : Icons.videocam_rounded,
            color: aud ? c.accInk : c.pinkInk, size: s * .48),
      );

  Widget nameText(String n, {double size = 15}) => Text(n,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.ltr,
      textAlign: ar ? TextAlign.right : TextAlign.left,
      style: TextStyle(
          color: c.ink, fontSize: size, fontWeight: FontWeight.w700));

  Widget box(Widget child, {EdgeInsets? pad, double r = 22}) => Container(
        padding: pad ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: c.line)),
        child: child,
      );

  Widget segmented(List<String> labels, int sel, ValueChanged<int> on,
          {Color? bg, List<IconData>? icons}) =>
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: bg ?? c.bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => on(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: sel == i ? c.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icons != null) ...[
                      Icon(icons[i],
                          size: 18, color: sel == i ? c.accInk : c.mute),
                      const SizedBox(width: 8),
                    ],
                    Text(labels[i],
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                sel == i ? FontWeight.w700 : FontWeight.w600,
                            color: sel == i ? c.accInk : c.mute)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  Widget wordmark(double size) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Flix',
              style: TextStyle(
                  color: c.ink,
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic)),
          ShaderMask(
            shaderCallback: (r) =>
                const LinearGradient(colors: brandGrad).createShader(r),
            child: Text('Go',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic)),
          ),
        ]),
      );

  Widget title(String s) => Text(s,
      style:
          TextStyle(color: c.ink, fontSize: 28, fontWeight: FontWeight.w800));

  // ---------- splash ----------

  Widget splash() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(children: [
            const Spacer(flex: 2),
            Image.asset('assets/logo.png', width: 300, fit: BoxFit.contain),
            const SizedBox(height: 4),
            Text(t('tag'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xEBFFFFFF), fontSize: 18, height: 1.6)),
            const Spacer(flex: 4),
            GestureDetector(
              onTap: () => setState(() => started = true),
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(colors: btnGrad)),
                child: Text(t('start'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('v1.0.0',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Color(0xE0FFFFFF), fontSize: 13)),
          ]),
        ),
      );

  // ---------- home ----------

  Widget homePage() {
    final status = url.text.isEmpty
        ? ''
        : blocked
            ? t('blocked')
            : valid
                ? ''
                : t('bad');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Row(children: [
          Image.asset('assets/mark.png', width: 44, height: 44),
          const SizedBox(width: 8),
          wordmark(24),
          const Spacer(),
          GestureDetector(
            onTap: () => setTab(3),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line)),
              child: Icon(Icons.tune_rounded, color: c.ink, size: 22),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Text(t('h1'),
            style: TextStyle(
                color: c.ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.35)),
        const SizedBox(height: 20),
        box(
          Column(children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: err ? c.pinkInk : Colors.transparent)),
              child: Row(children: [
                Icon(Icons.link_rounded, color: c.mute, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: url,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.url,
                    textDirection: url.text.isEmpty ? null : TextDirection.ltr,
                    style: TextStyle(color: c.ink, fontSize: 15),
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: t('ph'),
                        hintStyle: TextStyle(color: c.mute, fontSize: 14)),
                  ),
                ),
                GestureDetector(
                  onTap: paste,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: c.tint, borderRadius: BorderRadius.circular(12)),
                    child: Text(t('paste'),
                        style: TextStyle(
                            color: c.accInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(status,
                      style: TextStyle(color: c.pinkInk, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 14),
            segmented([t('audio'), t('video')], audio ? 0 : 1,
                (i) => setState(() => audio = i == 0),
                icons: const [Icons.music_note_rounded, Icons.videocam_rounded]),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: start,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: btnGrad),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.download_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(t('go'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text(t('hint'),
                style: TextStyle(color: c.mute, fontSize: 13, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Text(t('recent'),
              style: TextStyle(
                  color: c.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(
            onTap: () => setTab(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t('all'),
                  style: TextStyle(
                      color: c.accInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        if (items.isEmpty)
          Text(t('noDl'), style: TextStyle(color: c.mute, fontSize: 14)),
        for (final i in items.take(2)) itemCard(i),
      ],
    );
  }

  // ---------- downloads ----------

  Widget itemCard(Item i) {
    final failed = i.error != null;
    final sub = failed
        ? '${t('failed')}: ${i.error}'
        : i.done
            ? '${mbOf(i.total > 0 ? i.total : i.got)}${t('mb')}'
            : i.total > 0
                ? '${mbOf(i.got)} ${t('of')} ${mbOf(i.total)}${t('mb')}'
                : '...';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: box(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            tile(i.audio, 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nameText(i.name),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.mute, fontSize: 13)),
                  ]),
            ),
            const SizedBox(width: 8),
            if (i.done)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: c.ok, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              )
            else if (failed)
              Icon(Icons.error_outline_rounded, color: c.pinkInk)
            else
              GestureDetector(
                onTap: () => cancelItem(i),
                child: Semantics(
                  label: t('cancelDl'),
                  button: true,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: c.bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.close_rounded, color: c.ink, size: 20),
                  ),
                ),
              ),
          ]),
          if (!i.done && !failed) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: i.total > 0 ? i.pr / 100 : null,
                      minHeight: 8,
                      backgroundColor: c.tint,
                      color: c.acc),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text('${i.pr.floor()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: c.accInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ]),
        pad: const EdgeInsets.all(12),
        r: 20,
      ),
    );
  }

  Widget downloadsPage() {
    final act = items.where((i) => !i.done).toList();
    final fin = items.where((i) => i.done).toList();
    final list = dlTab == 0 ? act : fin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        title(t('dl')),
        const SizedBox(height: 18),
        segmented(['${t('active')} (${act.length})', '${t('doneTab')} (${fin.length})'],
            dlTab, (i) => setState(() => dlTab = i),
            bg: c.tint),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              Icon(Icons.inbox_rounded, size: 52, color: c.mute),
              const SizedBox(height: 10),
              Text(t('noDl'), style: TextStyle(color: c.mute)),
            ]),
          ),
        for (final i in list) itemCard(i),
      ],
    );
  }

  // ---------- library ----------

  Future<void> confirmDelete(LibFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: c.card,
          title: Text(t('delQ'), style: TextStyle(color: c.ink, fontSize: 17)),
          content: Text(f.name,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: c.mute)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('del'),
                    style: TextStyle(color: c.pinkInk))),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        if (f.remote) {
          await api().delete('/files/${Uri.encodeComponent(f.name)}');
        } else {
          await f.f?.delete();
        }
      } catch (_) {}
      loadLib();
    }
  }

  Widget libraryPage() {
    final term = q.text.trim().toLowerCase();
    final shown = lib.where((f) {
      if (filter == 1 && !f.audio) return false;
      if (filter == 2 && f.audio) return false;
      return term.isEmpty || f.name.toLowerCase().contains(term);
    }).toList();
    final total = lib.fold<int>(0, (s, f) => s + f.len);
    final chips = [t('fAll'), t('fAudio'), t('fVideo')];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              title(t('lib')),
              const Spacer(),
              Text('${lib.length} ${t('files')} · ${mbOf(total)}${t('mb')}',
                  style: TextStyle(color: c.mute, fontSize: 13)),
            ]),
        const SizedBox(height: 14),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line)),
          child: Row(children: [
            Icon(Icons.search_rounded, color: c.mute, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: q,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: c.ink, fontSize: 15),
                decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: t('search'),
                    hintStyle: TextStyle(color: c.mute, fontSize: 14)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < chips.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () => setState(() => filter = i),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      gradient: filter == i
                          ? const LinearGradient(colors: btnGrad)
                          : null,
                      color: filter == i ? null : c.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: filter == i ? Colors.transparent : c.line)),
                  child: Text(chips[i],
                      style: TextStyle(
                          color: filter == i ? Colors.white : c.mute,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(t('emptyLib'), style: TextStyle(color: c.mute)))
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: .95),
                  itemCount: shown.length,
                  itemBuilder: (_, k) {
                    final f = shown[k];
                    return GestureDetector(
                      onLongPress: () => confirmDelete(f),
                      child: box(
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: f.audio ? c.tint : c.pinkBg,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Icon(
                                      f.audio
                                          ? Icons.music_note_rounded
                                          : Icons.videocam_rounded,
                                      size: 36,
                                      color: f.audio ? c.accInk : c.pinkInk),
                                ),
                              ),
                              const SizedBox(height: 10),
                              nameText(f.name, size: 14),
                              Text('${mbOf(f.len)}${t('mb')}',
                                  style: TextStyle(
                                      color: c.mute, fontSize: 12)),
                            ]),
                        pad: const EdgeInsets.all(10),
                        r: 20,
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  // ---------- settings ----------

  Widget settingsPage() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        children: [
          title(t('set')),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(t('save'),
                style: TextStyle(
                    color: c.mute, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          box(
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: c.tint, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.folder_rounded, color: c.accInk, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t('folder'),
                          style: TextStyle(
                              color: c.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(savePath.isEmpty ? '...' : savePath,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: ar ? TextAlign.right : TextAlign.left,
                          style: TextStyle(color: c.mute, fontSize: 12)),
                    ]),
              ),
            ]),
          ),
          ...serverSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(t('look'),
                style: TextStyle(
                    color: c.mute, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            segmented([t('light'), t('dark')], dark ? 1 : 0,
                (i) => setState(() => dark = i == 1)),
            const SizedBox(height: 14),
            Text(t('lang'),
                style: TextStyle(
                    color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            segmented(['العربية', 'English'], ar ? 0 : 1,
                (i) => setState(() => ar = i == 0)),
          ])),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: dark ? const Color(0xFF3A2E12) : const Color(0xFFFFF4DE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: dark
                        ? const Color(0xFF6B5420)
                        : const Color(0xFFF3D9A4))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded,
                  size: 22,
                  color: dark
                      ? const Color(0xFFFFD27A)
                      : const Color(0xFF8A5A00)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t('note'),
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: dark
                            ? const Color(0xFFFFE3AE)
                            : const Color(0xFF5C3D00))),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              Text(t('about'), style: TextStyle(color: c.mute, fontSize: 13)),
              const Spacer(),
              Text('v1.0.0',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: c.mute, fontSize: 13)),
            ]),
          ),
        ],
      );

  Widget field(TextEditingController ctl, String hint, ValueChanged<String> on,
          {bool ltr = false, bool obscure = false}) =>
      Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: c.bg, borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctl,
          obscureText: obscure,
          onChanged: on,
          textDirection: ltr ? TextDirection.ltr : null,
          style: TextStyle(color: c.ink, fontSize: 14),
          decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: c.mute, fontSize: 13)),
        ),
      );

  List<Widget> serverSection() => [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(t('server'),
              style: TextStyle(
                  color: c.mute, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(t('useServer'),
                  style: TextStyle(
                      color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Switch(
              value: useServer,
              activeTrackColor: c.acc,
              thumbColor: WidgetStateProperty.all(Colors.white),
              onChanged: (v) {
                setState(() => useServer = v);
                savePrefs();
                loadLib();
              },
            ),
          ]),
          if (useServer) ...[
            const SizedBox(height: 10),
            field(urlCtl, t('srvUrl'), (v) {
              serverUrl = v.trim();
              savePrefs();
            }, ltr: true),
            const SizedBox(height: 10),
            field(tokenCtl, t('srvToken'), (v) {
              serverToken = v.trim();
              savePrefs();
            }, ltr: true, obscure: true),
            const SizedBox(height: 12),
            Row(children: [
              GestureDetector(
                onTap: testServer,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.tint, borderRadius: BorderRadius.circular(14)),
                  child: Text(t('srvTest'),
                      style: TextStyle(
                          color: c.accInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(serverMsg,
                    style: TextStyle(color: c.mute, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(t('srvHint'),
                style: TextStyle(color: c.mute, fontSize: 12.5, height: 1.6)),
          ],
        ])),
      ];

  // ---------- navigation ----------

  Widget navItem(int i, IconData icon, String label) {
    final sel = tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setTab(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                  color: sel ? c.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, size: 22, color: sel ? c.accInk : c.mute),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                    color: sel ? c.accInk : c.mute)),
          ]),
        ),
      ),
    );
  }

  Widget nav() => Container(
        decoration: BoxDecoration(
            color: c.card, border: Border(top: BorderSide(color: c.line))),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: SafeArea(
          top: false,
          child: Row(children: [
            navItem(0, Icons.home_rounded, t('home')),
            navItem(1, Icons.download_rounded, t('dl')),
            navItem(2, Icons.grid_view_rounded, t('lib')),
            navItem(3, Icons.tune_rounded, t('set')),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pages = [homePage, downloadsPage, libraryPage, settingsPage];
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: started ? c.bg : Colors.black,
        body: started
            ? Column(children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: pages[tab](),
                      ),
                    ),
                  ),
                ),
                nav(),
              ])
            : splash(),
      ),
    );
  }
}
