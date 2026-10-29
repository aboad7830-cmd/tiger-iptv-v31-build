# TIGER IPTV — الإصدار 3.0.0

> تحديث شامل: تنفيذ حزمة الـ100 ميزة كاملة + دعم جميع أجهزة Apple بواجهات متناسقة.

---

## 1) دعم جميع أجهزة Apple

| الجهاز | الحالة | ملاحظات |
|---|---|---|
| iPhone | ✅ مدعوم | تخطيط عمودين، شرائط سفلية، إيماءات لمس |
| iPad | ✅ مدعوم | تخطيط 3–4 أعمدة، شريط تبويبات جانبي (`.sidebarAdaptable`) |
| Mac (Catalyst / Designed for iPad) | ✅ مدعوم | مؤشّر، اختصارات لوحة مفاتيح، نافذة قابلة للتحجيم |
| Apple TV | ✅ مدعوم | محرّك تركيز (Focus Engine)، بطاقات مكبّرة، بلا لمس |
| Vision Pro | ✅ مدعوم | تخطيط مكاني، اتجاهات نافذة مُعلنة |

### طبقة المنصات الجديدة `Platform/TigerPlatform.swift`
- `TigerPlatformKind` (phone / pad / mac / tv / vision) مع أسماء عربية وأيقونات.
- `TigerPlatform`: `screenScale`، `screenSize`، `deviceModel`، `systemDescription`، `displayName`، `supportsHaptics`، `supportsPiP`، `trailingPlacement`، `searchPlacement`، `supportsSidebarTabs`، `readableMaxWidth`.
- `TigerAdaptiveMetrics`: كل القياسات (أعمدة الشبكة، حشوة المحتوى، ارتفاع البطل، أحجام الخطوط، أقصى عرض مقروء) مشتقّة من حجم الشاشة وفئة الحجم والمنصة.
- `TigerResponsiveGrid` شبكة متجاوبة موحّدة لكل الشاشات.
- `TigerHaptics` بديل موحّد لمحرّكات الاهتزاز.
- مُعدِّلات: `.tigerAdaptiveMetrics()`، `.tigerReadableWidth()`، `.tigerContentPadding()`، `.tigerFocusCard()`، `.tigerTVHoverEffect()`، `.tigerInlineNavigationTitle()`، `.tigerHiddenTabBar()`.

### إصلاحات التوافق
- إزالة `UIScreen.main` من كل طبقة التخطيط والصور والقياسات (استُبدل بـ `TigerPlatform`).
- إزالة `UIDevice` من شاشات التشخيص والأدوات السريعة والمزامنة.
- استبدال `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator` بـ `TigerHaptics`.
- استبدال `.navigationBarTrailing` بـ `.primaryAction` و`.navigationBarDrawer` بـ `TigerPlatform.searchPlacement` في 8 ملفات.
- إضافة أغلفة `#if os(iOS)` / `#else` بديلة لـ: `AirPlayRouteButton`، `ZoomableImageView`، `PlayerMediaKitStyleTouchOverlay`، `SystemVolumeBridge`، `QRScannerView`، `ShareSheet`، `PlayerLayerView` (AppKit fallback)، `AppDelegate`.
- `Pasteboard` موحّد (UIKit / AppKit / لا شيء).
- `project.yml`: `supportedDestinations: [iOS, iPadOS, tvOS, macOS, visionOS]` + `TARGETED_DEVICE_FAMILY: "1,2,3,6"`.

> **ملاحظة تقنية:** محرّك التشغيل libmpv يُشحن كـ xcframeworks لـ iOS فقط داخل `Vendor/libmpv`.
> الكود محمي بالكامل بـ `#if`، ولتشغيل الفيديو على tvOS/macOS/visionOS أضف شرائح libmpv المقابلة
> إلى `Vendor/libmpv` (أو استخدم مسار AVPlayer البديل).

---

## 2) حزمة Tiger Plus — 100 ميزة منفَّذة

`Features/FeaturePack300/` — 10 تصنيفات، 47 مساراً، 9 ملفات، ~4,300 سطر.

### التصنيفات
1. **البحث والاكتشاف** — بحث موحّد (قنوات/أفلام/مسلسلات)، تطبيع عربي، سجل بحث، بحث صوتي، فلاتر متقدمة.
2. **المشغّل** — إيماءات قابلة للضبط، تخطي المقدمة والملخص، التشغيل التلقائي للحلقة التالية، استئناف ذكي، طابور تشغيل.
3. **الاكتشاف** — توصيات، صفوف ذكية، اكتشاف عشوائي، محتوى مشابه، غير المشاهد، حلقات جديدة.
4. **المكتبة** — قوائم مخصصة، تقييمات شخصية، تصدير/استيراد JSON، تتبّع الإكمال.
5. **البث المباشر** — فحص صحة القناة، فحص شامل، إعادة ترتيب القنوات.
6. **التحميلات** — جدولة ليلية، حصة تخزين، حماية التحميل، إخلاء LRU.
7. **الأمان** — قفل التطبيق بالبصمة/PIN، ملفات تعريف، إشعارات، مشاركة QR.
8. **النظام** — توفير الطاقة، بدء بارد، تشخيص، تقارير.
9. **المظهر** — الخطوط، التخطيط، الأورورا، أيقونات التطبيق، مظهر لكل ملف.
10. **إمكانية الوصول** — تسميات، ترتيب تركيز، Switch Control، ترجمة على الجهاز.

### الملفات
| الملف | المحتوى |
|---|---|
| `TigerFeatureRegistry.swift` | 100 ميزة، 10 تصنيفات، 47 مساراً، مخزن مفاتيح |
| `TigerPlusCenter.swift` | مركز Tiger Plus + موجّه المسارات + مكوّنات إعدادات مشتركة |
| `TigerPlusSearch.swift` | محرّك البحث الموحّد، السجل، الفلاتر، البحث الصوتي |
| `TigerPlusPlayer.swift` | تفضيلات المشغّل، تخطي المقدمة، التالي تلقائياً، طابور التشغيل |
| `TigerPlusDiscovery.swift` | 9 شاشات اكتشاف + شبكة بوسترات + هيكل موحّد |
| `TigerPlusLive.swift` | فحص صحة القنوات + إعادة الترتيب |
| `TigerPlusLibrary.swift` | قوائم مخصصة، تقييمات، تصدير/استيراد، تتبّع إكمال |
| `TigerPlusSystem.swift` | التحميلات، القفل، الملفات، الإشعارات، المشاركة، الطاقة |
| `TigerPlusAppearance.swift` | الخطوط، التخطيط، الأورورا، الأيقونات، مظهر لكل ملف |

---

## 3) نقاط الدخول الجديدة
- `DashboardView` → قائمة «…» → **Tiger Plus (100 ميزة)**.
- `SettingsHubView` → قسم «المزايا» → **Tiger Plus (100 ميزة)**.

---

## 4) التحقق
- فحص توازن الأقواس/الأقواس المعقوفة على كل ملفات Swift: **0 اختلال**.
- فحص تكرار أسماء الأنواع على مستوى المشروع: **0 تكرار**.
- فحص الرموز الخاصة بـ iOS خارج حمايات `#if`: **0 متبقٍ**.

---

## 5) الترقيم
- `MARKETING_VERSION`: **3.0.0**
- `CURRENT_PROJECT_VERSION`: **30**
