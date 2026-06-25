import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/ad_helper.dart';
import '../theme/colors.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;

  const BannerAdWidget({super.key, this.adSize = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isError = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          if (mounted) {
            setState(() {
              _isError = true;
            });
          }
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adSize != oldWidget.adSize) {
      _bannerAd?.dispose();
      _isLoaded = false;
      _isError = false;
      _loadAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Center(
        child: SizedBox(
          width: widget.adSize.width.toDouble(),
          height: widget.adSize.height.toDouble(),
          child: AdWidget(key: ObjectKey(_bannerAd!), ad: _bannerAd!),
        ),
      );
    }

    // Cyber-styled loading/error placeholder to match the game aesthetic
    return Center(
      child: Container(
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
        decoration: BoxDecoration(
          color: CyberTheme.cardBg,
          border: Border.all(
            color: _isError
                ? CyberTheme.neonPink.withValues(alpha: 0.3)
                : CyberTheme.neonCyan.withValues(alpha: 0.15),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isError) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CyberTheme.neonCyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CONNECTING TELEMETRY LINK...',
                style: CyberTheme.fontCode(
                  size: 8.5,
                  color: CyberTheme.neonCyan,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.link_off_rounded,
                color: CyberTheme.neonPink,
                size: 12.0,
              ),
              const SizedBox(width: 6),
              Text(
                'LINK OFFLINE',
                style: CyberTheme.fontCode(
                  size: 8.5,
                  color: CyberTheme.neonPink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
