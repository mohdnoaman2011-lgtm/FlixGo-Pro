#!/usr/bin/env python3
"""
يجهّز مجلد android/ الذي ولّده `flutter create` لمشروع FlixGo:
  - الصلاحيات وخدمة الإشعارات واسم التطبيق في AndroidManifest.xml
  - تفعيل desugaring (مطلوب لحزمة الإشعارات)
  - إعداد توقيع النسخة النهائية من android/key.properties
  - نسخ الأيقونات (android_res/) إلى android/app/src/main/res/

الاستخدام (من جذر المشروع):  python3 tools/setup_android.py
آمن للتشغيل أكثر من مرة.
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
MANIFEST = ANDROID / "app/src/main/AndroidManifest.xml"
RES_SRC = ROOT / "android_res"
RES_DST = ANDROID / "app/src/main/res"

APP_LABEL = "FlixGo"

PERMISSIONS = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>',
]

SERVICE = """    <service
        android:name="com.dexterous.flutterlocalnotifications.ForegroundService"
        android:exported="false"
        android:foregroundServiceType="dataSync"
        android:stopWithTask="false"/>
"""

KTS_IMPORTS = """import java.io.FileInputStream
import java.util.Properties

"""

KTS_HEADER = """val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

"""

GROOVY_HEADER = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""

KTS_SIGNING = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

"""

GROOVY_SIGNING = """    signingConfigs {
        release {
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
            storeFile keystoreProperties["storeFile"] ? file(keystoreProperties["storeFile"]) : null
            storePassword keystoreProperties["storePassword"]
        }
    }

"""


NETWORK_SECURITY = """<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- يسمح بـ HTTP للخادم المحلي على الهاتف فقط؛ بقية الاتصالات تبقى HTTPS -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
"""


def log(msg):
    print(msg)


def patch_manifest():
    if not MANIFEST.exists():
        sys.exit(f"لم أجد {MANIFEST}. شغّل أولاً: flutter create --platforms=android --org com.flixgo --project-name flixgo .")
    text = MANIFEST.read_text(encoding="utf-8")
    orig = text

    # الصلاحيات (قبل <application)
    missing = [p for p in PERMISSIONS if re.search(re.escape(re.search(r'android:name="([^"]+)"', p).group(1)), text) is None]
    if missing:
        block = "\n".join("    " + p for p in missing) + "\n"
        text = re.sub(r"(\s*)<application", lambda m: "\n" + block + "    <application", text, count=1)

    # اسم التطبيق
    text = re.sub(r'(<application[^>]*?android:label=")[^"]*(")', rf"\g<1>{APP_LABEL}\g<2>", text, count=1, flags=re.S)

    # السماح بالاتصال بالخادم المحلي (HTTP) على 127.0.0.1 فقط
    nsc = RES_DST / "xml" / "network_security_config.xml"
    nsc.parent.mkdir(parents=True, exist_ok=True)
    nsc.write_text(NETWORK_SECURITY, encoding="utf-8")
    if "networkSecurityConfig" not in text:
        text = re.sub(r"(<application\b)", r'\1 android:networkSecurityConfig="@xml/network_security_config"', text, count=1)

    # خدمة الإشعارات
    if "flutterlocalnotifications.ForegroundService" not in text:
        text = text.replace("</application>", SERVICE + "    </application>", 1)

    if text != orig:
        MANIFEST.write_text(text, encoding="utf-8")
        log("✓ AndroidManifest.xml")
    else:
        log("• AndroidManifest.xml (لا تغيير)")


def patch_gradle():
    kts = ANDROID / "app/build.gradle.kts"
    groovy = ANDROID / "app/build.gradle"
    if kts.exists():
        path, is_kts = kts, True
    elif groovy.exists():
        path, is_kts = groovy, False
    else:
        sys.exit("لم أجد android/app/build.gradle(.kts)")

    text = path.read_text(encoding="utf-8")
    orig = text

    # 1) desugaring
    if "coreLibraryDesugaring" not in text:
        flag = "isCoreLibraryDesugaringEnabled = true" if is_kts else "coreLibraryDesugaringEnabled true"
        if re.search(r"compileOptions\s*\{", text):
            text = re.sub(r"(compileOptions\s*\{)", r"\1\n        " + flag, text, count=1)
        else:
            text = re.sub(r"(\nandroid\s*\{)", r"\1\n    compileOptions {\n        " + flag + "\n    }", text, count=1)
        dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if is_kts
               else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
        if re.search(r"^dependencies\s*\{", text, flags=re.M):
            text = re.sub(r"(^dependencies\s*\{)", r"\1\n    " + dep, text, count=1, flags=re.M)
        else:
            text = text.rstrip() + f"\n\ndependencies {{\n    {dep}\n}}\n"

    # 2) التوقيع
    if "keystoreProperties" not in text:
        header = KTS_HEADER if is_kts else GROOVY_HEADER
        signing = KTS_SIGNING if is_kts else GROOVY_SIGNING
        # يجب أن يبقى plugins {} أول جملة؛ لذا نضع التعريف قبل android { لا في أول الملف
        text = re.sub(r"(\nandroid\s*\{)", "\n" + header.rstrip("\n") + "\n" + r"\1", text, count=1)
        if is_kts:
            text = KTS_IMPORTS + text
        text = re.sub(r"(\n\s*buildTypes\s*\{)", "\n" + signing.rstrip("\n") + r"\1", text, count=1)
        if is_kts:
            text = re.sub(
                r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                'signingConfig = if (keystoreProperties.getProperty("storeFile") != null) '
                'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
                text,
            )
        else:
            text = re.sub(
                r"signingConfig\s*=?\s*signingConfigs\.debug",
                "signingConfig keystoreProperties['storeFile'] ? signingConfigs.release : signingConfigs.debug",
                text,
            )

    if text != orig:
        path.write_text(text, encoding="utf-8")
        log(f"✓ {path.relative_to(ROOT)}")
    else:
        log(f"• {path.relative_to(ROOT)} (لا تغيير)")


def copy_res():
    if not RES_SRC.exists():
        log("• android_res/ غير موجود؛ تخطّيت الأيقونات")
        return
    n = 0
    for src in RES_SRC.rglob("*"):
        if src.is_file():
            dst = RES_DST / src.relative_to(RES_SRC)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            n += 1
    # أيقونة Flutter الافتراضية القديمة قد تتعارض مع النسخة التكيفية (نفس الاسم بصيغتين)
    for d in RES_DST.glob("mipmap-*"):
        for stale in d.glob("ic_launcher.webp"):
            stale.unlink()
    log(f"✓ نُسخ {n} ملف أيقونة إلى res/")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    copy_res()
    log("\nتم. الخطوة التالية: flutter pub get ثم flutter run")
