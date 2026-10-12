import Foundation

/// How a category is called and drawn where there is little room for its API name:
/// the category row of Home, the chips of Explore, the kicker of the detail.
struct CategoryStyle: Equatable {
    let label: String
    let symbol: String
}

enum Categories {
    /// The API's name has stray spaces in it ("Partes e Peças ", "Sucatas , …"), so
    /// the lookup trims first. A category this table does not know keeps its name
    /// and a tag, never an empty icon.
    static func style(for name: String) -> CategoryStyle {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return table[key] ?? CategoryStyle(label: key, symbol: "tag")
    }

    private static let table: [String: CategoryStyle] = [
        "Imóveis": .init(label: "Imóveis", symbol: "building.2"),
        "Carros & Motos": .init(label: "Carros & Motos", symbol: "car"),
        "Caminhões & Ônibus": .init(label: "Caminhões", symbol: "box.truck"),
        "Máquinas Pesadas & Agrícolas": .init(label: "Máquinas pesadas", symbol: "gearshape.2"),
        "Movimentação & Transporte": .init(label: "Movimentação", symbol: "shippingbox"),
        "Industrial, Máquinas & Equipamentos": .init(label: "Indústria", symbol: "wrench.and.screwdriver"),
        "Animais": .init(label: "Animais", symbol: "pawprint"),
        "Tecnologia": .init(label: "Tecnologia", symbol: "laptopcomputer"),
        "Móveis e Decoração": .init(label: "Móveis", symbol: "chair.lounge"),
        "Bolsas, Canetas, Joias e Relógios": .init(label: "Joias e relógios", symbol: "watch.analog"),
        "Sucatas , Materiais & Resíduos": .init(label: "Sucatas", symbol: "arrow.3.trianglepath"),
        "Embarcações & Aeronaves": .init(label: "Barcos e aviões", symbol: "sailboat"),
        "Eletrodomésticos": .init(label: "Eletro", symbol: "refrigerator"),
        "Materiais para Construção Civil": .init(label: "Construção", symbol: "hammer"),
        "Cozinhas e Restaurantes": .init(label: "Cozinhas", symbol: "fork.knife"),
        "Alimentos e Bebidas": .init(label: "Alimentos", symbol: "cup.and.saucer"),
        "Oportunidades": .init(label: "Oportunidades", symbol: "tag"),
        "Artes, Decoração & Colecionismo": .init(label: "Arte e coleção", symbol: "paintpalette"),
        "Partes e Peças": .init(label: "Partes e peças", symbol: "gearshape"),
    ]
}
