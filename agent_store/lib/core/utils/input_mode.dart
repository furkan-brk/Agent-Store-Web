// lib/core/utils/input_mode.dart

import 'package:flutter/gestures.dart';

enum InputMode { mouse, touch, touchpad }

class InputModeDetector {
  static InputMode current = InputMode.mouse;

  static void detectFromPointerEvent(PointerEvent event) {
    switch (event.kind) {
      case PointerDeviceKind.touch:
        current = InputMode.touch;
        break;
      case PointerDeviceKind.trackpad:
        current = InputMode.touchpad;
        break;
      default:
        current = InputMode.mouse;
    }
  }

  static bool get isTouch => current == InputMode.touch;
  static bool get isTouchpad => current == InputMode.touchpad;
  static bool get isMouse => current == InputMode.mouse;

  static double get portHitSize => isTouch ? 44.0 : 28.0;
  static double get portSnapDistance => isTouch ? 44.0 : 28.0;
  static double get minNodeTouchTarget => isTouch ? 48.0 : 40.0;
  static double get zoomStep => isTouchpad ? 0.01 : 0.05;
}
