import SwiftUI

/// مقاسات البطاقات والملصقات — متكيّفة مع iPhone / iPad / Mac / Apple TV / Vision Pro.
///
/// المرجع الأساسي: آيباد 11" (أقصر ضلع ~834 pt). على الأجهزة الأكبر (Mac/TV) يكبر
/// المقياس، وعلى الآيفون يصغر، مع حدود دنيا/عليا تمنع التشويه.
struct PosterMetrics: Equatable, Sendable {
    /// 1.0 = مرجع آيباد 11"; الآيفون ~0.46–0.65، التلفاز ~1.35.
    let layoutScale: CGFloat

    init(layoutScale: CGFloat) {
        self.layoutScale = min(1.35, max(0.42, layoutScale))
    }

    init(windowSize: CGSize, sizeClass: UserInterfaceSizeClass? = nil, platform: TigerPlatformKind = TigerPlatform.kind) {
        let metrics = TigerAdaptiveMetrics(
            width: windowSize.width,
            height: windowSize.height,
            sizeClass: sizeClass,
            platform: platform
        )
        self.init(layoutScale: metrics.layoutScale)
    }

    init(metrics: TigerAdaptiveMetrics) {
        self.init(layoutScale: metrics.layoutScale)
    }

    // MARK: - الملصقات

    var shelfPosterWidth: CGFloat { scaled(200) }
    var shelfPosterHeight: CGFloat { scaled(300) }

    var categoryGridPosterWidth: CGFloat { scaled(200) }
    var categoryGridPosterHeight: CGFloat { scaled(300) }

    var searchGridMinWidth: CGFloat { scaled(110) }
    var searchCardWidth: CGFloat { scaled(160) }
    var searchCardHeight: CGFloat { scaled(240) }

    var liveShelfIcon: CGFloat { scaled(112) }
    var liveShelfLabelWidth: CGFloat { scaled(116) }
    var liveGridIconSize: CGFloat { scaled(180) }

    var searchLiveRowIcon: CGFloat { scaled(50) }
    var searchLiveRowLeadingInset: CGFloat { scaled(50) + 20 }

    var seriesDetailHeroWidth: CGFloat { scaled(118) }
    var seriesDetailHeroHeight: CGFloat { scaled(176) }

    var seasonStripWidth: CGFloat { scaled(120) }
    var seasonStripHeight: CGFloat { scaled(180) }

    var episodeThumbWidth: CGFloat { scaled(100) }
    var episodeThumbHeight: CGFloat { scaled(150) }
    var episodeRowDividerLeading: CGFloat { scaled(100) + 28 }

    var gridSpacing: CGFloat { scaled(16) }
    var gridRowSpacing: CGFloat { scaled(20) }
    var searchGridSpacing: CGFloat { scaled(12) }
    var searchSectionRowSpacing: CGFloat { scaled(16) }

    /// Raf satırı: poster + başlık alanı (yaklaşık 2 satır caption).
    var shelfRowTotalHeight: CGFloat { shelfPosterHeight + scaled(64) }

    /// بطاقة بطل الشاشة الرئيسية (Hero) — تتكيّف مع المنصّة.
    var heroHeight: CGFloat {
        let base: CGFloat
        switch TigerPlatform.kind {
        case .tv: base = 520
        case .mac: base = 400
        case .vision: base = 420
        case .pad: base = 380
        default: base = 300
        }
        return scaled(base)
    }

    // MARK: - فكّ ترميز الصور

    /// Kategori detay grid'i için prefetch boyutu (.grid profiliyle eşleşir)
    func prefetchCategoryDecodePixelSize() -> CGSize {
        let s = min(TigerPlatform.screenScale, 2)
        return CGSize(
            width: ceil(categoryGridPosterWidth * s),
            height: ceil(categoryGridPosterHeight * s)
        )
    }

    /// Yatay raf önizlemesi için prefetch boyutu (.shelf profiliyle eşleşir)
    func prefetchShelfDecodePixelSize() -> CGSize {
        let s = min(TigerPlatform.screenScale, 2)
        return CGSize(
            width: ceil(shelfPosterWidth * s),
            height: ceil(shelfPosterHeight * s)
        )
    }

    private func scaled(_ base: CGFloat) -> CGFloat {
        (base * layoutScale).rounded(.toNearestOrAwayFromZero)
    }
}

private struct PosterMetricsKey: EnvironmentKey {
    static var defaultValue: PosterMetrics {
        PosterMetrics(windowSize: TigerPlatform.screenSize)
    }
}

extension EnvironmentValues {
    var posterMetrics: PosterMetrics {
        get { self[PosterMetricsKey.self] }
        set { self[PosterMetricsKey.self] = newValue }
    }
}
