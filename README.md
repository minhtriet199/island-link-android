# island-link-android

Pixel / Android side of **Island Link**: a light phone ↔ PC link for the Island shell (Hyprland, CachyOS).

- Phone notifications → Island bubbles on the PC
- Download mode on the phone: live progress bar, "finished" notice, Shut down · Cancel · Launch · Open buttons
- Basic remote controls (media, volume, lock, sleep, shutdown)

Flutter (Dart) app, with a small native Android part for the always-on pieces. No Google Play Services. Pairs once by QR code with the PC helper:
[island-link-pc](https://github.com/minhtriet199/island-link-pc). Same Wi-Fi only for now.

Status: just started.
