import XCTest
@testable import Lote

/// The title cleanup against its reference, docs/design-v3/tidy_title.py: first the
/// vectors of that file, then the golden table of the 1,566 real titles the
/// reference produced. The golden is the contract; a disagreement is a bug in the
/// port, never a reason to edit the table.
final class LotTitleTests: XCTestCase {

    // Same vectors as `VECTORS` in tidy_title.py. A nil headline means "already
    // readable, must come back untouched".
    private let vectors: [(raw: String, headline: String?, detail: String?)] = [
        ("CHEVROLET CLASSIC LS 2010 2011 CINZA", "Chevrolet Classic LS 2010/2011 Cinza", nil),
        ("VW GOL GL 2P 1989 1989 CINZA", "VW Gol GL 2P 1989/1989 Cinza", nil),
        ("RENAULT CLIO PRI 10 16VH 2004 2004 CINZA", "Renault Clio PRI 10 16VH 2004/2004 Cinza", nil),
        ("CHEVROLET SPIN 18L AT PREMIER, 2024/2025, Placa FINAL 0 (SP), (Ref.: 53137)",
         "Chevrolet Spin 18L AT Premier, 2024/2025, Placa Final 0 (SP)", nil),
        ("TOYOTA/COROLLA XEI20FLEX, 2016/2017, AZUL", "Toyota/Corolla XEI20FLEX, 2016/2017, Azul", nil),
        ("M.BENZ/LK 1313 - Ano/Modelo 1987/1987 - Combustível DIESEL",
         "M.Benz/LK 1313 - Ano/Modelo 1987/1987 - Combustível Diesel", nil),
        ("EMPILHADEIRA TOYOTA 8FG25 DIESEL ID: #3614548", "Empilhadeira Toyota 8FG25 Diesel", nil),
        ("LAVADORA E TANQUINHO (#50MAGO)", "Lavadora e Tanquinho", nil),
        ("CHEVROLET TRACKER 12T A RS, 2023/2024, Placa FINAL 2 (SP), (Ref.: 53166)",
         "Chevrolet Tracker 12T A RS, 2023/2024, Placa Final 2 (SP)", nil),
        ("FIAT PALIO ELX EDX 1.0 MPI 1998 1999 CINZA", "Fiat Palio ELX EDX 1.0 MPI 1998/1999 Cinza", nil),
        ("NOVILHA NELORE - ATHENA FIV SNL - SNL 1517", "Novilha Nelore - Athena FIV SNL - SNL 1517", nil),
        ("TRATOR JOHN DEERE 6110E 4X4 ANO 2014 1.185 HORAS", "Trator John Deere 6110E 4X4 Ano 2014 1.185 Horas", nil),
        ("Máquina de escrever Antiga OLIVETTI LINEA 98", "Máquina de escrever Antiga Olivetti Linea 98", nil),
        ("121 UNIDADES NOVAS ¿ BOX PARA CAMA, BOX BAÚ, CAMAS AUXILIARES E CABECEIRAS",
         "121 Unidades Novas – Box para Cama, Box Baú, Camas Auxiliares e Cabeceiras", nil),
        ("¿¿UM TELEVISOR, MARCA SHARP, 32 POLEGADAS e UM REFRIGERADOR",
         "Um Televisor, Marca Sharp, 32 Polegadas e um Refrigerador", nil),
        ("Casa 78m² com Terreno 300m² | Rosário Do Sul-RS | Vila Nova - Financiamento até 420 Meses!",
         "Casa 78m² com Terreno 300m²", "Rosário Do Sul-RS · Vila Nova - Financiamento até 420 Meses!"),
        ("Apartamento 114,97m², Jardim Monte Alegre, Itapecerica da Serra/SP",
         "Apartamento 114,97m², Jardim Monte Alegre, Itapecerica da Serra/SP", nil),
        ("TORNO MECÂNICO DE PRECISÃO SANCHES COM PLACA UNIVERSAL",
         "Torno Mecânico de Precisão Sanches com Placa Universal", nil),
        ("NELORE MOCHA - MAAB EMPINADO - MABY 5297", "Nelore Mocha - Maab Empinado - Maby 5297", nil),
        ("Geladeira, freezer, ar condicionado, máquina de lavar roupas", nil, nil),
    ]

    func testTheReferenceVectors() {
        for (raw, headline, detail) in vectors {
            let result = TitleTidy.tidy(raw)
            XCTAssertEqual(result.headline, headline ?? raw, "headline of \(raw)")
            XCTAssertEqual(result.detail, detail, "detail of \(raw)")
        }
    }

    func testTheSeparatorBetweenDetailPartsBecomesAMiddleDot() {
        let result = TitleTidy.tidy("Casa 56m² | Santana da Vargem-MG | São Luiz | Financiamento em até 420 Meses!")
        XCTAssertEqual(result.headline, "Casa 56m²")
        XCTAssertEqual(result.detail, "Santana da Vargem-MG · São Luiz · Financiamento em até 420 Meses!")
    }

    func testATitleThatIsOnlyNoiseDoesNotCrashAndHasNoDetail() {
        XCTAssertEqual(TitleTidy.tidy("").headline, "")
        XCTAssertNil(TitleTidy.tidy("").detail)
        XCTAssertEqual(TitleTidy.tidy("(Ref.: 1)").headline, "")
        XCTAssertNil(TitleTidy.tidy("Casa | ").detail)
    }

    func testTheDisplayFallsBackToTheRawTitleWhenNothingIsLeft() {
        let lot = LotDisplayTests.summary(title: "(Ref.: 1)")
        XCTAssertEqual(LotDisplay(lot).title, "(Ref.: 1)")
    }

    func testTheTitleCacheAnswersWhatTheFunctionAnswers() {
        let raw = "FIAT PALIO ELX EDX 1.0 MPI 1998 1999 CINZA"
        XCTAssertEqual(TitleCache.tidy(raw), TitleTidy.tidy(raw))
        XCTAssertEqual(TitleCache.tidy(raw), TitleTidy.tidy(raw))
    }

    // MARK: golden

    /// The golden table is owned by the backend repo, which sits beside this one. Found from
    /// this file's own path: the tests run in a simulator process sharing the host filesystem.
    private var goldenFile: URL {
        let relative = "docs/design-v3/tidy_title_golden.tsv"
        let workspace = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // LoteTests
            .deletingLastPathComponent()  // ios
        let candidates = [
            workspace.deletingLastPathComponent().appendingPathComponent("backend/" + relative),
            workspace.appendingPathComponent(relative),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    func testEveryRealTitleOfTheGoldenTableComesOutExactlyAsTheReferenceMadeIt() throws {
        let golden = goldenFile
        guard FileManager.default.fileExists(atPath: golden.path) else {
            XCTFail("The golden table is missing: expected \(golden.path). The title cleanup cannot be verified without it.")
            return
        }
        let text = try String(contentsOf: golden, encoding: .utf8)
        var rows = text.components(separatedBy: "\n")
        if rows.last == "" { rows.removeLast() }
        XCTAssertEqual(rows.count, 1_566, "the golden table is expected to hold 1,566 titles")

        var mismatches: [String] = []
        for (number, row) in rows.enumerated() {
            let columns = row.components(separatedBy: "\t")
            guard columns.count == 3 else {
                XCTFail("row \(number + 1) has \(columns.count) columns instead of 3: \(row)")
                continue
            }
            let (raw, headline, detail) = (columns[0], columns[1], columns[2])
            let result = TitleTidy.tidy(raw)
            // Compared scalar by scalar: Swift's own == treats canonically equivalent
            // strings as equal, which would hide a difference in composition.
            let sameHeadline = Array(result.headline.unicodeScalars) == Array(headline.unicodeScalars)
            let sameDetail = Array((result.detail ?? "").unicodeScalars) == Array(detail.unicodeScalars)
            if !sameHeadline || !sameDetail {
                mismatches.append("row \(number + 1): \(raw)\n   want: \(headline) | \(detail)\n   got:  \(result.headline) | \(result.detail ?? "")")
            }
        }
        XCTAssertTrue(
            mismatches.isEmpty,
            "\(mismatches.count) of \(rows.count) titles differ from the reference:\n" + mismatches.prefix(20).joined(separator: "\n"))
    }
}
