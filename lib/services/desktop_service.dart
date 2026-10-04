import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows-only: window setup and the always-on-top "mini widget" mode,
/// the desktop counterpart of the Android home screen widget.
class DesktopService extends ChangeNotifier {
  static bool get supported => !kIsWeb && Platform.isWindows;

  bool mini = false;
  Rect? _savedBounds;

  static Future<void> init() async {
    if (!supported) return;
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 820),
      minimumSize: Size(400, 600),
      center: true,
      title: 'Rituel',
      backgroundColor: Color(0xFF0B0C14),
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> enterMini({bool alwaysOnTop = true}) async {
    if (!supported) return;
    _savedBounds = await windowManager.getBounds();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    await windowManager.setMinimumSize(const Size(300, 260));
    await windowManager.setSize(const Size(340, 500));
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    mini = true;
    notifyListeners();
  }

  Future<void> exitMini() async {
    if (!supported) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(const Size(400, 600));
    if (_savedBounds != null) {
      await windowManager.setBounds(_savedBounds);
    } else {
      await windowManager.setSize(const Size(1180, 820));
      await windowManager.center();
    }
    mini = false;
    notifyListeners();
  }
}
