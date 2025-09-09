//  ContentView.swift
//  Single-file SwiftUI app (iOS / iPadOS) for a doll dress-up game.
//
//  ✅ Drop this ONE file into your SwiftUI target.
//  ✅ Add PNG assets to Assets.xcassets with these names:
//     - "dollBase"
//     - "tshirt", "tshirt1", "tshirt2", "jacket"
//     - "skirt", "shorts", "shorts2"
//     - "hat1", "hat2", "shoes1", "shoes2", "acc1"
//  ✅ Build & run. Works on iPhone and iPad.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Models

struct ClothingItem: Identifiable, Hashable {
    enum Category: String, CaseIterable, Codable {
        case top, bottom, hat, shoes, accessory, hair
        
        var displayName: String {
            switch self {
            case .top:       return "Tops"
            case .bottom:    return "Bottoms"
            case .hat:       return "Hats"
            case .hair:      return "Hair"
            case .shoes:     return "Shoes"
            case .accessory: return "Accessories"
            }
        }
    }
    
    let id = UUID()
    let name: String
    let category: Category
}

// MARK: - Persistence

private enum OutfitStore {
    static let equippedKey = "rumy.equippedNames.v1"
    
    static func save(_ map: [ClothingItem.Category: ClothingItem]) {
        let dict = map.mapKeys(\.rawValue).mapValues(\.name)
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: equippedKey)
        }
    }
    
    static func load() -> [String: String]? {
        guard let data = UserDefaults.standard.data(forKey: equippedKey) else { return nil }
        return try? JSONDecoder().decode([String:String].self, from: data)
    }
}

private extension Dictionary {
    func mapKeys<T>(_ transform: (Key) throws -> T) rethrows -> [T: Value] where T: Hashable {
        var new: [T: Value] = [:]
        for (k, v) in self { new[try transform(k)] = v }
        return new
    }
}

// MARK: - ViewModel

@MainActor
final class DressUpViewModel: ObservableObject {
    @Published private(set) var catalog: [ClothingItem] = []
    @Published private(set) var equipped: [ClothingItem.Category: ClothingItem] = [:]
    
    init() {
        self.catalog = [
            .init(name: "tshirt",  category: .top),
            .init(name: "tshirt1", category: .top),
            .init(name: "tshirt2", category: .top),
            .init(name: "jacket",  category: .top),
            .init(name: "skirt",   category: .bottom),
            .init(name: "shorts",  category: .bottom),
            .init(name: "shorts2", category: .bottom),
            .init(name: "hat1",    category: .hat),
            .init(name: "hat2",    category: .hat),
            .init(name: "hair",    category: .hat),
            .init(name: "shoes1",  category: .shoes),
            .init(name: "shoes2",  category: .shoes),
            .init(name: "acc1",    category: .accessory),
            .init(name: "acc2",    category: .accessory)
        ]
        
        if let saved = OutfitStore.load() {
            var restored: [ClothingItem.Category: ClothingItem] = [:]
            for (keyRaw, assetName) in saved {
                if let cat = ClothingItem.Category(rawValue: keyRaw),
                   let item = catalog.first(where: { $0.name == assetName && $0.category == cat }) {
                    restored[cat] = item
                }
            }
            self.equipped = restored
        }
    }
    
    func items(for categories: [ClothingItem.Category]) -> [ClothingItem] {
        catalog.filter { categories.contains($0.category) }
    }
    func isEquipped(_ item: ClothingItem) -> Bool {
        equipped[item.category]?.name == item.name
    }
    func equip(_ item: ClothingItem) {
        equipped[item.category] = item; persist()
    }
    func unequip(category: ClothingItem.Category) {
        equipped.removeValue(forKey: category); persist()
    }
    func toggle(_ item: ClothingItem) {
        if isEquipped(item) { unequip(category: item.category) }
        else { equip(item) }
    }
    func reset() {
        equipped.removeAll(); persist()
    }
    func randomize() {
        var new: [ClothingItem.Category: ClothingItem] = [:]
        for cat in ClothingItem.Category.allCases {
            let options = catalog.filter { $0.category == cat }
            if let pick = options.randomElement(),
               Bool.random() || cat == .top || cat == .bottom {
                new[cat] = pick
            }
        }
        equipped = new; persist()
    }
    private func persist() {
        OutfitStore.save(equipped)
    }
}

// MARK: - Share (Identifiable payload for reliable iPad first-tap)

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var vm = DressUpViewModel()
    @State private var sharePayload: SharePayload?   // <- .sheet(item:) friendly
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(
                    title: "Rumy DressUp",
                    iconSystemName: "tshirt",
                    onReset: { vm.reset() },
                    onRandom: { vm.randomize() },
                    onExport: { shareText() }   // text-only share
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                Divider().opacity(0.25)
                
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        WardrobeColumn(
                            title: "Tops / Bottoms",
                            items: vm.items(for: [.top, .bottom]),
                            isSelected: { vm.isEquipped($0) },
                            tapped: { vm.toggle($0) }
                        )
                        .frame(width: columnWidth(for: geo.size))
                        
                        ZStack {
                            Color(UIColor.systemGroupedBackground)
                                .ignoresSafeArea()
                            DollCanvas(equipped: vm.equipped)
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        WardrobeColumn(
                            title: "Hats / Shoes / Accessories",
                            items: vm.items(for: [.hat, .hair, .shoes, .accessory]),
                            isSelected: { vm.isEquipped($0) },
                            tapped: { vm.toggle($0) }
                        )
                        .frame(width: columnWidth(for: geo.size))
                    }
                }
            }
            // Use .sheet(item:) so the first tap presents reliably on iPad
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func columnWidth(for size: CGSize) -> CGFloat {
        size.width < 740 ? 112 : 210
    }
    
    // MARK: - Share text (no image); Dispatch to main to avoid first-tap no-op
    private func shareText() {
        let appURL = "https://apps.apple.com/app/idXXXXXXXXXX" // replace when ready
        let message = """
        Hey! Check out this cute Rumi dress-up app 👗✨
        Create outfits, style and share looks! 
        """
        DispatchQueue.main.async {
            self.sharePayload = SharePayload(items: [message])
        }
    }
}

// MARK: - Header

struct AppHeader: View {
    let title: String
    let iconSystemName: String
    let onReset: () -> Void
    let onRandom: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconSystemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer()
            
            HStack(spacing: 8) {
                HeaderButton(systemName: "arrow.counterclockwise", label: "Reset", action: onReset)
                HeaderButton(systemName: "wand.and.stars", label: "Random", action: onRandom)
                HeaderButton(systemName: "square.and.arrow.up", label: "Share", action: onExport)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HeaderButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.body.weight(.semibold))
                Text(label)
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Doll Canvas

struct DollCanvas: View {
    let equipped: [ClothingItem.Category: ClothingItem]
    var body: some View {
        GeometryReader { g in
            ZStack {
                Image("dollBase")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(g.size.height * 0.92, 700))
                if let bottom = equipped[.bottom] {
                    LayeredImage(name: bottom.name, h: min(g.size.height * 0.92, 700))
                }
                if let top = equipped[.top] {
                    LayeredImage(name: top.name, h: min(g.size.height * 0.92, 700))
                }
                if let shoes = equipped[.shoes] {
                    LayeredImage(name: shoes.name, h: min(g.size.height * 0.92, 700))
                }
                if let acc = equipped[.accessory] {
                    LayeredImage(name: acc.name, h: min(g.size.height * 0.92, 700))
                }
                if let hat = equipped[.hat] {
                    LayeredImage(name: hat.name, h: min(g.size.height * 0.92, 700))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LayeredImage: View {
    let name: String
    let h: CGFloat
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: h)
            .accessibilityHidden(true)
    }
}

// MARK: - Wardrobe & Helpers

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WardrobeColumn: View {
    let title: String
    let items: [ClothingItem]
    let isSelected: (ClothingItem) -> Bool
    let tapped: (ClothingItem) -> Void
    
    @State private var containerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    private var canScrollUp: Bool { scrollOffset > 2 }
    private var canScrollDown: Bool { (contentHeight - scrollOffset - containerHeight) > 2 }
    private var coordSpaceName: String { "wardrobeScroll.\(title)" }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)
            ZStack {
                GeometryReader { outerGeo in
                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(
                                GeometryReader { g in
                                    Color.clear
                                        .preference(key: ScrollOffsetKey.self, value: -g.frame(in: .named(coordSpaceName)).minY)
                                }
                            )
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                WardrobeCell(
                                    item: item,
                                    isSelected: isSelected(item),
                                    action: { tapped(item) }
                                )
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                            }
                        )
                    }
                    .coordinateSpace(name: coordSpaceName)
                    .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
                    .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
                    .onChange(of: outerGeo.size.height) { _, newHeight in
                        containerHeight = newHeight
                    }
                    .onAppear { containerHeight = outerGeo.size.height }
                }
                if canScrollUp {
                    VStack { LinearGradient(gradient: Gradient(colors: [Color(UIColor.systemBackground).opacity(0.95), .clear]), startPoint: .top, endPoint: .bottom).frame(height: 24); Spacer() }
                        .overlay(alignment: .top) {
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(.top, 2)
                        }
                }
                if canScrollDown {
                    VStack { Spacer(); LinearGradient(gradient: Gradient(colors: [.clear, Color(UIColor.systemBackground).opacity(0.95)]), startPoint: .top, endPoint: .bottom).frame(height: 24) }
                        .overlay(alignment: .bottom) {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(.bottom, 2)
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: canScrollUp)
            .animation(.easeInOut(duration: 0.2), value: canScrollDown)
        }
        .background(BlurView(style: .systemThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(10)
    }
}

struct WardrobeCell: View {
    let item: ClothingItem
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.0001)).frame(width: 76, height: 76)
                    Image(item.name).resizable().scaledToFit().frame(width: 72, height: 72)
                }
                Text(itemDisplayName)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 82)
            }
            .padding(6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
    private var itemDisplayName: String {
        item.name.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").map { $0.localizedCapitalized }.joined(separator: " ")
    }
}

// MARK: - Blur + Share

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

// GoodDeeds-style ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 15 Pro")
        ContentView().previewDevice("iPad (10th generation)")
    }
}
