import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop, tv }

class ResponsiveBreakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 900;
  static const double tv = 1920;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  bool get isMobile => screenWidth < ResponsiveBreakpoints.tablet;
  bool get isTablet => screenWidth >= ResponsiveBreakpoints.tablet && screenWidth < ResponsiveBreakpoints.desktop;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.desktop && screenWidth < ResponsiveBreakpoints.tv;
  bool get isTv => screenWidth >= ResponsiveBreakpoints.tv;
  
  ScreenType get screenType {
    if (isTv) return ScreenType.tv;
    if (isDesktop) return ScreenType.desktop;
    if (isTablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }
  
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
  
  /// 是否是宽屏（平板以上）
  bool get isWideScreen => screenWidth >= ResponsiveBreakpoints.tablet;
  
  /// 根据屏幕类型返回不同值
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? tv,
  }) {
    switch (screenType) {
      case ScreenType.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }
}
