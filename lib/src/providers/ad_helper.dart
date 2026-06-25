import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Android Test Banner ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner ID
      }
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-6886595543105921/6040920463';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6886595543105921/6232492157';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Android Test Rewarded ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded ID
      }
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-6886595543105921/8826865907';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6886595543105921/3766110910';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedInterstitialAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5354046379'; // Android Test Rewarded Interstitial ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6978759866'; // iOS Test Rewarded Interstitial ID
      }
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-6886595543105921/8826865907';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6886595543105921/3766110910';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
