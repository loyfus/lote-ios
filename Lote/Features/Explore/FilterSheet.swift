import SwiftUI

/// The filter sheet: what a lot is, when it closes, what it costs and how the result
/// is ordered. The sheet edits a draft; nothing changes behind it until "Mostrar" and
/// closing it any other way leaves the filters as they were. The button at the foot
/// says how many lots the draft would show, asked of the server as the user chooses.
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repository: LoteRepository
    /// The search and the category are not edited here but narrow the count, so
    /// "Mostrar N lotes" is the number the grid will actually show.
    let search: String
    let category: String?
    let onApply: (ExploreFilters) -> Void

    @State private var draft: ExploreFilters
    @State private var count: Int?
    @State private var detent: PresentationDetent = .large
    @FocusState private var focusedBound: PriceBound?

    init(
        repository: LoteRepository, search: String, category: String?, initial: ExploreFilters,
        onApply: @escaping (ExploreFilters) -> Void
    ) {
        self.repository = repository
        self.search = search
        self.category = category
        self.onApply = onApply
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Tipo") { modalityChoices }
                    section("Prazo") { deadlineChoices }
                    section("Faixa de preço") { priceChoices }
                    section("Ordenar por") { sortChoices }
                }
                .padding(.bottom, Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Palette.paper)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Palette.paper)
        .task(id: countKey) { await refreshCount() }
        .toolbar {
            // The number pad has no return key of its own.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Concluído") { focusedBound = nil }
            }
        }
    }

    // MARK: Layout

    private var header: some View {
        HStack {
            Text("Filtros")
                .typeset(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.ink60)
                    .frame(width: Palette.touch, height: Palette.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Fechar")
        }
        .padding(.leading, Space.gutter)
        .padding(.trailing, Space.sm)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xs)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .typeset(.cardTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.gutter)
        .padding(.top, 14)
        .padding(.bottom, Space.xs)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: Space.md) {
                SecondaryButton(title: "Limpar") { draft = ExploreFilters() }
                    .fixedSize(horizontal: true, vertical: false)
                PrimaryButton(title: showTitle) {
                    onApply(draft)
                    dismiss()
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.sm)
        }
        .background(Palette.paper)
    }

    private var showTitle: String {
        guard let count else { return "Ver resultados" }
        return count == 1 ? "Mostrar 1 lote" : "Mostrar \(Fmt.thousands(count)) lotes"
    }

    // MARK: Choices

    private var modalityChoices: some View {
        FlowLayout {
            Chip(title: "Todos", isSelected: draft.modality == nil) { draft.modality = nil }
            ForEach(LotModality.allCases, id: \.self) { modality in
                Chip(title: modality.label, isSelected: draft.modality == modality) { draft.modality = modality }
            }
        }
    }

    private var deadlineChoices: some View {
        FlowLayout {
            ForEach(ExploreFilters.deadlines, id: \.title) { deadline in
                Chip(title: deadline.title, isSelected: draft.endsWithin == deadline.hours) {
                    draft.endsWithin = deadline.hours
                }
            }
        }
    }

    private static let priceShortcuts: [(title: String, min: Int?, max: Int?)] = [
        ("Até 1 mil", nil, 1_000),
        ("1 – 10 mil", 1_000, 10_000),
        ("10 – 50 mil", 10_000, 50_000),
        ("50 – 200 mil", 50_000, 200_000),
        ("Acima de 200 mil", 200_000, nil),
    ]

    private var priceChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PriceField(label: "Mínimo", bound: .min, value: $draft.minPrice, focus: $focusedBound)
                PriceField(label: "Máximo", bound: .max, value: $draft.maxPrice, focus: $focusedBound)
            }
            FlowLayout {
                ForEach(Self.priceShortcuts, id: \.title) { shortcut in
                    let selected = draft.minPrice == shortcut.min && draft.maxPrice == shortcut.max
                    Chip(title: shortcut.title, isSelected: selected) {
                        // A second tap on the chosen range takes it back.
                        draft.minPrice = selected ? nil : shortcut.min
                        draft.maxPrice = selected ? nil : shortcut.max
                        focusedBound = nil
                    }
                }
            }
        }
    }

    private var sortChoices: some View {
        FlowLayout {
            ForEach(LotSort.allCases) { sort in
                Chip(title: sort.label, isSelected: draft.sort == sort) { draft.sort = sort }
            }
        }
    }

    // MARK: Live count

    /// The order does not change how many lots there are, so only the filters that
    /// narrow the catalogue restart the count.
    private var countKey: ExploreFilters {
        var key = draft
        key.sort = .ending
        return key
    }

    private func refreshCount() async {
        count = nil
        // The user is still choosing: ask once they stop.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let query = LotQuery(
            search: search, category: category, modality: draft.modality?.rawValue,
            endsWithin: draft.endsWithin, minPrice: draft.minPrice, maxPrice: draft.maxPrice,
            sort: .ending, page: 0, size: 1)
        guard let page = try? await repository.lots(query), !Task.isCancelled else { return }
        count = page.totalElements
    }
}

private enum PriceBound: Hashable {
    case min
    case max
}

/// A price bound: digits only, grouped as they are typed.
private struct PriceField: View {
    let label: String
    let bound: PriceBound
    @Binding var value: Int?
    var focus: FocusState<PriceBound?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .typeset(.caption)
                .foregroundStyle(Palette.ink60)
            HStack(spacing: 6) {
                Text("R$")
                    .typeset(.factValue)
                    .foregroundStyle(value == nil ? Palette.ink60 : Palette.ink)
                TextField("", text: digits, prompt: Text("0").foregroundColor(Palette.ink60))
                    .font(TypeRole.factValue.font)
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.numberPad)
                    .focused(focus, equals: bound)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(Palette.surface, in: shape)
        .overlay { shape.strokeBorder(Palette.lineControl, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preço \(label.lowercased()), em reais")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
    }

    /// Whatever is typed or pasted, kept to its digits (nine of them: up to R$ 999
    /// milhões) and written back with thousands separators.
    private var digits: Binding<String> {
        Binding(
            get: { value.map(Fmt.thousands) ?? "" },
            set: { raw in
                let kept = raw.filter(\.isASCII).filter(\.isNumber).prefix(9)
                value = Int(kept)
            })
    }
}
