import SwiftUI

/// المزايا والتفعيلات — واجهة واحدة للتحكم في 200+ ميزة.
/// كل ميزة تُحفظ حالتها في UserDefaults، والمزايا الموصولة فعليًا فقط
/// تُطبّق أثرها على الواجهات، وما عداها يُعلَّم بوضوح «قيد التطوير».
struct FeatureCenterView: View {
    @StateObject private var flags = TigerFeatureFlags.shared
    @Environment(\.colorScheme) private var scheme

    @State private var searchText = ""
    @State private var selectedCategory: TigerFeatureCategory? = nil
    @State private var onlyEnabled = false
    @State private var selectedFeature: TigerFeature? = nil
    @State private var showResetAlert = false

    private var filtered: [TigerFeature] {
        var items = TigerFeatureCatalog.all
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        if onlyEnabled {
            items = items.filter { flags.isOn($0) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
                || $0.category.title.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    var body: some View {
        ZStack {
            TigerAdaptive.background(scheme)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header
                    tigerPlusLink
                    quickActions
                    searchField
                    categoryChips
                    featureList
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("المزايا والتفعيلات")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "ابحث في 200 ميزة…")
        .sheet(item: $selectedFeature) { feature in
            FeatureDetailSheet(feature: feature)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("إعادة ضبط المزايا؟", isPresented: $showResetAlert) {
            Button("إعادة الضبط", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    flags.resetToDefaults()
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم إرجاع كل المزايا إلى حالتها الافتراضية.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .stroke(TigerAdaptive.cardStroke(scheme), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        TigerTheme.orangeGradient,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(flags.enabledCount)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(TigerAdaptive.text(scheme))
                    Text("مفعّلة")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                }
            }
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 4) {
                Text("المزايا والتفعيلات")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TigerAdaptive.text(scheme))
                Text("\(flags.totalCount) ميزة قابلة للتحكم — تشغيل، صوت، ترجمة، بث، أفلام، مسلسلات، شبكة، خصوصية وإتاحة. جميع المزايا موصولة بمحرّك التنفيذ وتعمل فورًا عند التفعيل.")
                    .font(.caption)
                    .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(TigerAdaptive.cardFill(scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(TigerAdaptive.cardStroke(scheme), lineWidth: 1)
                )
        )
    }

    private var tigerPlusLink: some View {
        NavigationLink {
            TigerPlusCenterView(playlist: nil)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TigerTheme.gold)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(TigerTheme.gold.opacity(0.16))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("حزمة Tiger Plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TigerAdaptive.text(scheme))
                    Text("100 ميزة إضافية: بحث ذكي، مشغّل متقدم، أمان، مزامنة، مظهر")
                        .font(.caption2)
                        .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(TigerAdaptive.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(TigerTheme.gold.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var progress: Double {
        guard flags.totalCount > 0 else { return 0 }
        return Double(flags.enabledCount) / Double(flags.totalCount)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: Spacing.sm) {
            actionButton(icon: "checkmark.circle.fill", title: "تفعيل الكل", tint: TigerTheme.brandLight) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { flags.enableAll() }
            }
            actionButton(icon: "line.3.horizontal.decrease.circle", title: onlyEnabled ? "عرض الكل" : "المفعّلة فقط", tint: TigerTheme.gold) {
                withAnimation { onlyEnabled.toggle() }
            }
            actionButton(icon: "arrow.counterclockwise", title: "إعادة ضبط", tint: TigerTheme.orange) {
                showResetAlert = true
            }
        }
    }

    private func actionButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(tint.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
            TextField("ابحث باسم الميزة أو القسم…", text: $searchText)
                .foregroundStyle(TigerAdaptive.text(scheme))
                .tint(TigerTheme.orange)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(TigerAdaptive.fieldFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(TigerAdaptive.cardStroke(scheme), lineWidth: 1)
        )
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                chip(title: "الكل", icon: "square.grid.2x2.fill", active: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(TigerFeatureCategory.allCases) { category in
                    chip(
                        title: category.title,
                        icon: category.icon,
                        active: selectedCategory == category,
                        count: flags.enabledCount(in: category)
                    ) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, icon: String, active: Bool, count: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(title).font(.caption.weight(.semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.18)))
                }
            }
            .foregroundStyle(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(TigerAdaptive.secondaryText(scheme)))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(active ? AnyShapeStyle(TigerTheme.orangeGradient) : AnyShapeStyle(TigerAdaptive.chipFill(scheme)))
            )
            .overlay(
                Capsule().strokeBorder(active ? Color.clear : TigerAdaptive.chipStroke(scheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    private var featureList: some View {
        LazyVStack(spacing: Spacing.sm) {
            if filtered.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
                    Text("لا توجد ميزة مطابقة")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(filtered) { feature in
                    FeatureRow(feature: feature, flags: flags) {
                        selectedFeature = feature
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct FeatureRow: View {
    let feature: TigerFeature
    @ObservedObject var flags: TigerFeatureFlags
    var onTap: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(TigerTheme.orange.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TigerTheme.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(feature.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TigerAdaptive.text(scheme))
                        .lineLimit(1)
                    Text("#\(feature.number)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
                }
                Text(feature.detail)
                    .font(.caption2)
                    .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                    .lineLimit(2)
                if !TigerFeatureWiring.isWired(feature.id) {
                    Text("قيد التطوير")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(TigerTheme.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(TigerTheme.orange.opacity(0.14)))
                }
            }

            Spacer(minLength: 4)

            Toggle("", isOn: Binding(
                get: { flags.isOn(feature) },
                set: { on in
                    flags.set(feature.id, on)
                    TigerFeatureRuntime.shared.applySideEffects(for: feature.id, enabled: on)
                }
            ))
            .labelsHidden()
            .tint(TigerTheme.brandLight)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(TigerAdaptive.cardFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(TigerAdaptive.cardStroke(scheme), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Detail

private struct FeatureDetailSheet: View {
    let feature: TigerFeature
    @ObservedObject private var flags = TigerFeatureFlags.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            TigerAdaptive.background(scheme)
            VStack(spacing: Spacing.lg) {
                Capsule().fill(TigerAdaptive.cardStroke(scheme)).frame(width: 40, height: 5).padding(.top, 8)

                ZStack {
                    Circle().fill(TigerTheme.orange.opacity(0.18)).frame(width: 92, height: 92)
                    Image(systemName: feature.icon)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(TigerTheme.orangeGradient)
                }

                VStack(spacing: 6) {
                    Text(feature.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(TigerAdaptive.text(scheme))
                        .multilineTextAlignment(.center)
                    Text("الميزة رقم \(feature.number) • \(feature.category.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TigerTheme.orange)
                    Text(feature.detail)
                        .font(.subheadline)
                        .foregroundStyle(TigerAdaptive.secondaryText(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    if !TigerFeatureWiring.isWired(feature.id) {
                        Label("هذه الميزة تُحفظ حالتها الآن، وسيُفعّل أثرها في تحديث قادم.", systemImage: "hammer.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(TigerTheme.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, Spacing.lg)

                Toggle(isOn: Binding(
                    get: { flags.isOn(feature) },
                    set: { on in
                    flags.set(feature.id, on)
                    TigerFeatureRuntime.shared.applySideEffects(for: feature.id, enabled: on)
                }
                )) {
                    Text(flags.isOn(feature) ? "الميزة مفعّلة" : "الميزة متوقفة")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TigerAdaptive.text(scheme))
                }
                .tint(TigerTheme.brandLight)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(TigerAdaptive.cardFill(scheme))
                )
                .padding(.horizontal, Spacing.lg)

                Button {
                    dismiss()
                } label: {
                    Text("تم")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(TigerTheme.orangeGradient)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)

                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    NavigationStack { FeatureCenterView() }
}
