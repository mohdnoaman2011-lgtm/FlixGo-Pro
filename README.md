# FlixGo

## الخادم
    cd server
    docker build -t flixgo-server .
    docker run -p 8000:8000 -v flixgo-data:/data -e API_KEY=غيّرني flixgo-server

متغيرات اختيارية: ALLOWED_DOMAINS (أو `*`)، MAX_CONCURRENT، FILE_TTL_SECONDS،
MAX_FILESIZE_MB، COOKIES_FILE. فحص الإصدار: GET /api/health

## التطبيق
    cd app && flutter create . --project-name flixgo --org com.flixgo
    # انسخ lib/ و pubspec.yaml فوق الموجودين ثم:
    flutter pub get
    flutter run --dart-define=API_BASE=http://10.0.2.2:8000 --dart-define=API_KEY=غيّرني

أندرويد: أضف في AndroidManifest.xml
    <uses-permission android:name="android.permission.INTERNET"/>
وللتجربة على http بدل https: android:usesCleartextTraffic="true" على <application>.

## إعدادات منصّات إضافية
- أندرويد (`AndroidManifest.xml`): `INTERNET` و`POST_NOTIFICATIONS`، وللمعرض `WRITE_EXTERNAL_STORAGE` مع `android:maxSdkVersion="29"`.
- iOS (`Info.plist`): `NSPhotoLibraryAddUsageDescription` لنسخ الفيديو إلى الصور.
- يتطلب Flutter 3.22 أو أحدث.

## الشعار
الأصول في `app/assets/`. بعد `flutter pub get` ولّد أيقونة التطبيق وشاشة البداية:

    dart run flutter_launcher_icons
    dart run flutter_native_splash:create