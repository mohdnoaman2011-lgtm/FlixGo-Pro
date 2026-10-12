FlixGo server for Termux
========================

1) Install Termux (from F-Droid) and open it, then run once:

   pkg update -y && pkg install -y python
   termux-setup-storage

2) Copy flixgo_server.py to the phone (for example into Downloads), then:

   cp ~/storage/downloads/flixgo_server.py ~/
   termux-wake-lock
   python flixgo_server.py

   Files are saved to  ~/storage/downloads/FlixGo  (visible in the Files app).

3) In the FlixGo app: Settings > Server > turn on "Use download server",
   address:  http://127.0.0.1:8787   then press "Test connection".

Keep it running in the background:

   nohup python flixgo_server.py > server.log 2>&1 &

Optional settings (put them before the command):

   FLIXGO_TOKEN=mysecret python flixgo_server.py     # require a secret token
   FLIXGO_PORT=9000 python flixgo_server.py          # another port
   FLIXGO_DIR=~/mydir python flixgo_server.py        # another folder

Using it from another phone/computer on the same Wi-Fi:

   FLIXGO_HOST=0.0.0.0 FLIXGO_TOKEN=mysecret python flixgo_server.py
   (the server refuses to start on 0.0.0.0 without a token)
   In the app use  http://<phone-ip>:8787  and the same token.

Notes
- Direct https links only. YouTube / Instagram / TikTok / X / Facebook are refused.
- Links that point to local/private addresses are refused.
- Only download content you own or that is openly licensed.
