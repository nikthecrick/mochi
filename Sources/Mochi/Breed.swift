import Foundation

/// Random breeds: every pet hatches with its own colors.
struct Breed {
    let name: String
    let body: (Double, Double, Double)
    let shade: (Double, Double, Double)
    let blush: (Double, Double, Double)

    static let all: [Breed] = [
        Breed(name: "Mint",    body: (0.62, 0.87, 0.74), shade: (0.44, 0.71, 0.58), blush: (1.00, 0.66, 0.72)),
        Breed(name: "Peach",    body: (1.00, 0.78, 0.62), shade: (0.92, 0.60, 0.48), blush: (1.00, 0.56, 0.52)),
        Breed(name: "Lavender", body: (0.78, 0.70, 0.95), shade: (0.62, 0.55, 0.85), blush: (0.95, 0.60, 0.85)),
        Breed(name: "Sky",      body: (0.55, 0.75, 0.95), shade: (0.42, 0.60, 0.85), blush: (0.70, 0.80, 0.95)),
        Breed(name: "Sunny",   body: (0.98, 0.88, 0.50), shade: (0.85, 0.72, 0.34), blush: (1.00, 0.70, 0.60)),
        Breed(name: "Rose",    body: (1.00, 0.65, 0.72), shade: (0.88, 0.48, 0.60), blush: (1.00, 0.55, 0.65)),
        Breed(name: "Sage",    body: (0.72, 0.82, 0.55), shade: (0.55, 0.65, 0.40), blush: (0.90, 0.80, 0.60)),
        Breed(name: "Cocoa",   body: (0.72, 0.55, 0.45), shade: (0.55, 0.40, 0.33), blush: (0.85, 0.35, 0.45)),
    ]

    static func random() -> Breed { all.randomElement() ?? all[0] }
}