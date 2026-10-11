#!/data/data/com.termux/files/usr/bin/sh
# تشغيل خادم الاستخراج على هاتفك عبر Termux. الاستخدام: sh termux.sh
cd "$(dirname "$0")" || exit 1
if ! command -v node >/dev/null 2>&1; then
  echo "تثبيت Node.js..."
  pkg update -y && pkg install -y nodejs || exit 1
fi
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "تثبيت Python و yt-dlp لدعم المنصات العامة..."
  pkg install -y python ffmpeg || exit 1
  python -m pip install --upgrade yt-dlp || exit 1
fi
# يمنع النظام من إيقاف Termux أثناء التشغيل (اختياري، يتطلب Termux:API)
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
echo "الخادم يعمل على http://127.0.0.1:8080 — اتركه مفتوحاً وافتح FlixGo."
HOST_ONLY=1 PORT=8080 exec node server.js
