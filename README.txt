FlixGo - complete code
======================
main.dart                       -> the whole app (Flutter, lib/main.dart)
assets/                         -> logo.png, mark.png, icon.png
.github/workflows/build.yml     -> builds the APK on GitHub (Actions > Build APK > Run workflow)
server/                         -> optional download server for Termux (see server/README.txt)

Build on GitHub (from a phone browser):
1. Create a repository and upload everything in this folder, keeping the same structure
   (main.dart and assets/ at the top, build.yml inside .github/workflows/).
2. Actions > Build APK > Run workflow. Download the FlixGo artifact when it finishes.
