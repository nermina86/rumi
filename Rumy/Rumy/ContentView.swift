//Copyright © 2025 by Nermina Memišević
//All rights reserved. No part of this work may be reproduced,
//distributed, or transmitted in any form or by any means 

import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Models

struct ClothingItem: Identifiable, Hashable {
    enum Category: String, CaseIterable, Codable {
        case top, bottom, hat, hair, shoes, accessory
        
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
            .init(name: "hair",    category: .hair),
            .init(name: "hair2",   category: .hair),
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

// MARK: - Share payload

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - Parental Gate

struct BirthYearGateView: View {
    @Binding var isUnlocked: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var yearOfBirth = ""
    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(spacing: 20) {
            Text("Parents Only")
                .font(.headline)

            Text("Please enter your year of birth to continue")
                .multilineTextAlignment(.center)

            TextField("e.g. 1985", text: $yearOfBirth)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 120)

            Button("Unlock") {
                if let year = Int(yearOfBirth),
                   (currentYear - year) >= 18 {
                    isUnlocked = true
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var vm = DressUpViewModel()
    @State private var sharePayload: SharePayload?
    
    @State private var showParentalGate = false
    @State private var parentalGatePassed = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(
                    title: "DressUp",
                    iconSystemName: "tshirt",
                    onReset: { vm.reset() },
                    onRandom: { vm.randomize() },
                    onExport: { showParentalGate = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                Divider().opacity(0.25)
                
                GeometryReader { geo in
                    HStack(alignment: .top, spacing: 0) {
                        WardrobeColumn(
                            title: "Tops / Bottoms",
                            items: vm.items(for: [.top, .bottom]),
                            isSelected: { vm.isEquipped($0) },
                            tapped: { vm.toggle($0) }
                        )
                        .frame(width: columnWidth(for: geo.size))
                        
                        DollCanvas(equipped: vm.equipped)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        

                        WardrobeColumn(
                            title: "Hats/Shoes/Bags",
                            items: vm.items(for: [.hat, .shoes, .hair, .accessory]),
                            isSelected: { vm.isEquipped($0) },
                            tapped: { vm.toggle($0) }
                        )
                        .frame(width: columnWidth(for: geo.size))
                    }
                }
            }
            .sheet(isPresented: $showParentalGate) {
                BirthYearGateView(isUnlocked: $parentalGatePassed)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .onChange(of: parentalGatePassed) { old, new in
                if new {
                    shareText()
                    parentalGatePassed = false
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func columnWidth(for size: CGSize) -> CGFloat {
        size.width < 740 ? 110 : 250
    }
    
    private func shareText() {
        let appURL = "https://apps.apple.com/app/rummy-dressup/id6752292318"
        let message = """
        Hey! Check out this HUNDRIX Rumi dress-up app 👗✨
        Create outfits, styles and share looks! \(appURL)
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
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer()
            
            HStack(spacing: 12) {
                HeaderIconButton(systemName: "arrow.counterclockwise",
                                 label: "Reset",
                                 action: onReset)
                HeaderIconButton(systemName: "wand.and.stars",
                                 label: "Random",
                                 action: onRandom)
                HeaderIconButton(systemName: "square.and.arrow.up",
                                 label: "Share",
                                 action: onExport)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                .contentShape(Capsule())
                .accessibilityLabel(Text(label))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Doll Canvas with radiant background

struct DollCanvas: View {
    let equipped: [ClothingItem.Category: ClothingItem]
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.6)
                .ignoresSafeArea()
                
                Image("dollBase")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(g.size.height * 0.95, 850))
                
                if let bottom = equipped[.bottom] {
                    LayeredImage(name: bottom.name, h: min(g.size.height * 0.95, 850))
                }
                if let top = equipped[.top] {
                    LayeredImage(name: top.name, h: min(g.size.height * 0.95, 850))
                }
                if let shoes = equipped[.shoes] {
                    LayeredImage(name: shoes.name, h: min(g.size.height * 0.95, 850))
                }
                if let acc = equipped[.accessory] {
                    LayeredImage(name: acc.name, h: min(g.size.height * 0.95, 850))
                }
                if let hair = equipped[.hair] {
                    LayeredImage(name: hair.name, h: min(g.size.height * 0.95, 850))
                }
                if let hat = equipped[.hat] {
                    LayeredImage(name: hat.name, h: min(g.size.height * 0.95, 850))
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

// MARK: - Preference Keys

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

// MARK: - Wardrobe & Helpers (with purple dividers)

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
                                        .preference(
                                            key: ScrollOffsetKey.self,
                                            value: -g.frame(in: .named(coordSpaceName)).minY
                                        )
                                }
                            )
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                WardrobeCell(
                                    item: item,
                                    isSelected: isSelected(item),
                                    action: { tapped(item) }
                                )
                                .padding(.horizontal, 8)
                                
                                // purple divider between items
                                if index < items.count - 1 {
                                    Divider()
                                        .background(Color.purple)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: ContentHeightKey.self,
                                    value: g.size.height
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: coordSpaceName)
                    .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
                    .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
                    .onChange(of: outerGeo.size.height) { _, h in containerHeight = h }
                    .onAppear { containerHeight = outerGeo.size.height }
                }
                
                if canScrollUp {
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color(UIColor.systemBackground).opacity(0.95), .clear]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                        Spacer()
                    }
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
                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, Color(UIColor.systemBackground).opacity(0.95)]),
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                    }
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
        // radiant panel background
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.85), Color.pink.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(10)
        .shadow(radius: 4, y: 2)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(item.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .shadow(radius: 2)
                }
                
                Text(itemDisplayName)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 82)
            }
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(1), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Blur + Share

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        // Optional: exclude some activities for Kids apps
        vc.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 15 Pro")
        ContentView().previewDevice("iPad (10th generation)")
    }
}
