class AdService {
  int _taps = 0;
  static const int maxTapsToShowAds = 5;

  bool registerTapAndShouldShowAd() {
    _taps += 1;
    if (_taps >= maxTapsToShowAds) {
      _taps = 0;
      return true;
    }
    return false;
  }
}
