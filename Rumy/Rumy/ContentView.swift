//
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
    let name: String        // Asset name in the catalog / xcassets
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
        // Seed catalog with your initial assets (add more freely)
        self.catalog = [
            // Provided starter pieces
            .init(name: "tshirt",  category: .top),
            .init(name: "tshirt1", category: .top),
            .init(name: "tshirt2", category: .top),
            .init(name: "jacket",  category: .top),
            .init(name: "skirt",   category: .bottom),
            .init(name: "shorts",  category: .bottom),
            .init(name: "shorts2", category: .bottom),
            
            // Optional placeholders (replace with real assets when ready)
            .init(name: "hat1",    category: .hat),
            .init(name: "hat2",    category: .hat),
            .init(name: "hair",    category: .hat), // hair lives in its own category
            .init(name: "shoes1",  category: .shoes),
            .init(name: "shoes2",  category: .shoes),
            .init(name: "acc1",    category: .accessory),
            .init(name: "acc2",    category: .accessory)
        ]
        
        // Load persisted outfit if available
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
    
    // Filtering
    func items(for categories: [ClothingItem.Category]) -> [ClothingItem] {
        catalog.filter { categories.contains($0.category) }
    }
    
    func isEquipped(_ item: ClothingItem) -> Bool {
        equipped[item.category]?.name == item.name
    }
    
    func equip(_ item: ClothingItem) {
        equipped[item.category] = item
        persist()
    }
    
    func unequip(category: ClothingItem.Category) {
        equipped.removeValue(forKey: category)
        persist()
    }
    
    func toggle(_ item: ClothingItem) {
        if isEquipped(item) {
            unequip(category: item.category)
        } else {
            equip(item)
        }
    }
    
    func reset() {
        equipped.removeAll()
        persist()
    }
    
    func randomize() {
        var new: [ClothingItem.Category: ClothingItem] = [:]
        for cat in ClothingItem.Category.allCases {
            let options = catalog.filter { $0.category == cat }
            if let pick = options.randomElement(), Bool.random() || cat == .top || cat == .bottom {
                new[cat] = pick
            }
        }
        equipped = new
        persist()
    }
    
    private func persist() {
        OutfitStore.save(equipped)
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var vm = DressUpViewModel()
    @State private var exportURL: URL?
    @State private var isSharing = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left: Tops + Bottoms
                    WardrobeColumn(
                        title: "Tops / Bottoms",
                        items: vm.items(for: [.top, .bottom]),
                        isSelected: { vm.isEquipped($0) },
                        tapped: { vm.toggle($0) }
                    )
                    .frame(width: columnWidth(for: geo.size))
                    
                    // Center: Doll
                    ZStack {
                        Color(UIColor.systemGroupedBackground)
                            .ignoresSafeArea()
                        DollCanvas(equipped: vm.equipped)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Right: Hats + Shoes + Accessories (+ Hair)
                    WardrobeColumn(
                        title: "Hats / Shoes / Accessories",
                        items: vm.items(for: [.hat, .hair, .shoes, .accessory]),
                        isSelected: { vm.isEquipped($0) },
                        tapped: { vm.toggle($0) }
                    )
                    .frame(width: columnWidth(for: geo.size))
                }
            }
            .navigationTitle("Rumy DressUp")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        vm.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        vm.randomize()
                    } label: {
                        Label("Random", systemImage: "shuffle")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        exportOutfitImage()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .sheet(isPresented: $isSharing) {
                        if let exportURL {
                            ShareSheet(activityItems: [exportURL])
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func columnWidth(for size: CGSize) -> CGFloat {
        // Adaptive: narrower columns on compact width
        size.width < 740 ? 112 : 210
    }
    
    // Render + export
    private func exportOutfitImage() {
        // Render the center doll as an image
        let renderer = ImageRenderer(content:
            DollCanvas(equipped: vm.equipped)
                .frame(width: 1200, height: 1800) // matches asset canvas
                .background(Color.clear)
        )
        renderer.scale = 1.0
        
        guard let uiImage = renderer.uiImage else { return }
        
        // Save to a temporary PNG and present share sheet
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RumyOutfit-\(UUID().uuidString.prefix(6)).png")
        if let data = uiImage.pngData() {
            try? data.write(to: url)
            self.exportURL = url
            self.isSharing = true
        }
    }
}

// MARK: - Doll Canvas (layering)

struct DollCanvas: View {
    let equipped: [ClothingItem.Category: ClothingItem]
    
    var body: some View {
        GeometryReader { g in
            ZStack {
                // Base
                Image("dollBase")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(g.size.height * 0.92, 700))
                
                // Layering order: bottom -> top -> shoes -> accessory -> hat
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

// MARK: - Scroll measuring (for fade + chevrons)

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

// MARK: - Wardrobe (with fade + chevron indicators)

struct WardrobeColumn: View {
    let title: String
    let items: [ClothingItem]
    let isSelected: (ClothingItem) -> Bool
    let tapped: (ClothingItem) -> Void
    
    @State private var containerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    private var canScrollUp: Bool {
        scrollOffset > 2
    }
    private var canScrollDown: Bool {
        (contentHeight - scrollOffset - containerHeight) > 2
    }
    
    private var coordSpaceName: String { "wardrobeScroll.\(title)" }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)
            
            ZStack {
                GeometryReader { outerGeo in
                    ScrollView {
                        // Track scroll offset at the very top of content
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { g in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetKey.self,
                                            value: -g.frame(in: .named(coordSpaceName)).minY
                                        )
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
                        // Measure total content height
                        .background(
                            GeometryReader { g in
                                Color.clear
                                    .preference(key: ContentHeightKey.self, value: g.size.height)
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
                
                // ===== Top fade + chevron =====
                if canScrollUp {
                    VStack(spacing: 0) {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.systemBackground).opacity(0.95),
                                Color(UIColor.systemBackground).opacity(0.0)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                        .allowsHitTesting(false)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                    .overlay(alignment: .top) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(.top, 2)
                            .allowsHitTesting(false)
                    }
                }
                
                // ===== Bottom fade + chevron =====
                if canScrollDown {
                    VStack(spacing: 0) {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.systemBackground).opacity(0.0),
                                Color(UIColor.systemBackground).opacity(0.95)
                            ]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                        .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                    .overlay(alignment: .bottom) {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(.bottom, 2)
                            .allowsHitTesting(false)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: canScrollUp)
            .animation(.easeInOut(duration: 0.2), value: canScrollDown)
        }
        .background(BlurView(style: .systemThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(10)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Scroll to see more items")
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.0001)) // boost tap area without visible fill
                        .frame(width: 76, height: 76)
                    Image(item.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipped()
                }
                
                Text(itemDisplayName)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 82)
            }
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(itemDisplayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var itemDisplayName: String {
        item.name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.localizedCapitalized }
            .joined(separator: " ")
    }
}

// MARK: - Blur

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

// MARK: - Share Sheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        vc.excludedActivityTypes = [.assignToContact, .addToReadingList, .openInIBooks]
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("iPhone")
                .previewInterfaceOrientation(.landscapeLeft)
            
            ContentView()
                .previewDisplayName("iPad")
                .previewDevice("iPad (10th generation)")
        }
    }
}

struct WardrobeColumn_Previews: PreviewProvider {
    static var previews: some View {
        // Preview the wardrobe alone with many items to see arrow indicators
        WardrobeColumn(
            title: "Tops / Bottoms",
            items: (1...24).map { i in ClothingItem(name: "tshirt\(i)", category: .top) },
            isSelected: { _ in false },
            tapped: { _ in }
        )
        .frame(width: 210, height: 420)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Wardrobe with Scroll Arrows")
    }
}
