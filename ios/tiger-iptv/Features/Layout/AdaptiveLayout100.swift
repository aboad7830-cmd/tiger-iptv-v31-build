//
//  AdaptiveLayout100.swift
//  Tiger IPTV
//
//  تخطيطات متكيّفة (78–79)
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - بيئة المقاس

enum TigerLayoutMode: String, CaseIterable, Identifiable {
    case compactPhone
    case regularPhoneLandscape
    case padPortrait
    case padLandscape
    case tv

    var id: String { rawValue }

    static func current(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> TigerLayoutMode {
        #if os(tvOS)
        return .tv
        #else
        let isPad = horizontalSizeClass == .regular
        let isLandscape = size.width > size.height
        if isPad {
            return isLandscape ? .padLandscape : .padPortrait
        }
        return isLandscape ? .regularPhoneLandscape : .compactPhone
        #endif
    }

    var usesSidebar: Bool {
        self == .padLandscape || self == .padPortrait
    }

    var gridColumns: Int {
        switch self {
        case .compactPhone: return 3
        case .regularPhoneLandscape: return 5
        case .padPortrait: return 5
        case .padLandscape: return 7
        case .tv: return 6
        }
    }

    var contentMaxWidth: CGFloat? {
        switch self {
        case .padLandscape: return 1180
        case .padPortrait: return 820
        default: return nil
        }
    }
}

// MARK: - 78) شريط جانبي للـ iPad

struct TigerSidebarItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let symbol: String
}

struct TigerAdaptiveSidebar<ID: Hashable, Content: View>: View {
    @Binding var selection: ID
    let items: [TigerSidebarItem<ID>]
    @ViewBuilder var detail: () -> Content

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    Button {
                        selection = item.id
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(selection == item.id
                                          ? TigerTheme.gold.opacity(0.18)
                                          : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Tiger IPTV")
            .listStyle(.sidebar)
        } detail: {
            detail()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// يغلّف المحتوى بعرض أقصى مناسب للشاشات الكبيرة.
struct TigerContentWidthLimiter: ViewModifier {
    let maxWidth: CGFloat?

    func body(content: Content) -> some View {
        if let maxWidth {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func tigerContentWidth(_ maxWidth: CGFloat?) -> some View {
        modifier(TigerContentWidthLimiter(maxWidth: maxWidth))
    }
}

// MARK: - 79) تخطيط أفقي كامل (Landscape)

struct TigerLandscapeLayout<Leading: View, Trailing: View>: View {
    let ratio: CGFloat
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    init(
        ratio: CGFloat = 0.62,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.ratio = min(max(ratio, 0.3), 0.8)
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                leading()
                    .frame(width: geo.size.width * ratio)
                Divider()
                trailing()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// يختار بين تخطيط عمودي وأفقي حسب المساحة المتاحة.
struct TigerResponsiveSplit<Primary: View, Secondary: View>: View {
    let breakpoint: CGFloat
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= breakpoint {
                HStack(spacing: 0) {
                    primary().frame(maxWidth: .infinity)
                    Divider()
                    secondary().frame(width: min(360, geo.size.width * 0.34))
                }
            } else {
                VStack(spacing: 0) {
                    primary().frame(maxHeight: .infinity)
                    secondary().frame(maxHeight: geo.size.height * 0.4)
                }
            }
        }
    }
}

// MARK: - عرض شبكي متكيّف

struct TigerAdaptiveGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let mode: TigerLayoutMode
    let spacing: CGFloat
    @ViewBuilder var cell: (Item) -> Cell

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(2, mode.gridColumns))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(items) { item in
                    cell(item)
                }
            }
            .padding(spacing)
            .tigerContentWidth(mode.contentMaxWidth)
        }
    }
}

// MARK: - لوحة معاينة التخطيط

struct TigerLayoutPreviewView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mode: TigerLayoutMode = .compactPhone

    var body: some View {
        GeometryReader { geo in
            List {
                Section {
                    LabeledContent(L("layout.mode"), value: mode.rawValue)
                    LabeledContent(L("layout.columns"), value: "\(mode.gridColumns)")
                    LabeledContent(L("layout.sidebar"), value: mode.usesSidebar ? L("common.yes") : L("common.no"))
                    LabeledContent(L("layout.size"), value: "\(Int(geo.size.width))×\(Int(geo.size.height))")
                } header: {
                    Text(L("layout.current"))
                }

                Section {
                    ForEach(TigerLayoutMode.allCases) { item in
                        HStack {
                            Text(item.rawValue)
                            Spacer()
                            if item == mode {
                                Image(systemName: "checkmark").foregroundStyle(TigerTheme.gold)
                            }
                        }
                    }
                } header: {
                    Text(L("layout.all"))
                }
            }
        }
        .navigationTitle(L("layout.title"))
        .onAppear {
            mode = TigerLayoutMode.current(size: TigerPlatform.screenSize, horizontalSizeClass: horizontalSizeClass)
        }
    }
}
