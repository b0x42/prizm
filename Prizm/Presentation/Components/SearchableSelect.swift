import SwiftUI

struct SearchableSelectOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var systemImage: String?

    var id: Value { value }
}

struct SearchableSelect<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [SearchableSelectOption<Value>]
    var displaysLabel = true

    @State private var isPresented = false

    private var selectedTitle: String {
        options.first { $0.value == selection }?.title ?? "Select"
    }

    @ViewBuilder
    var body: some View {
        if displaysLabel {
            HStack(alignment: .center) {
                Text(title)
                    .font(Typography.fieldValue)
                Spacer()
                trigger
            }
        } else {
            trigger
        }
    }

    private var trigger: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: Spacing.searchableSelectGap) {
                Text(selectedTitle)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(Typography.utility)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(Typography.fieldValue)
            .padding(.horizontal, Spacing.searchableSelectPadding)
            .padding(.vertical, Spacing.searchableSelectGap)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: Spacing.badgeCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selectedTitle)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SearchableSelectPopover(
                title: title,
                selection: $selection,
                options: options
            ) {
                isPresented = false
            }
        }
    }
}

struct SearchableSelectPopover<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [SearchableSelectOption<Value>]
    let close: () -> Void

    @State private var query = ""
    @State private var highlightedValue: Value?
    @State private var scrollsToHighlightedValue = false
    @FocusState private var isSearchFocused: Bool

    private var filteredOptions: [SearchableSelectOption<Value>] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return options }
        return options.filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.searchableSelectGap) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Search \(title.lowercased())", text: $query)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isSearchFocused)
                    .onSubmit {
                        selectHighlightedOption()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Spacing.searchableSelectPopoverPadding)
            .padding(.vertical, Spacing.searchableSelectPadding)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    if filteredOptions.isEmpty {
                        Text("No results")
                            .font(Typography.fieldValue)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.pageMargin)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredOptions) { option in
                                optionRow(option)
                                    .id(option.id)
                            }
                        }
                        .padding(Spacing.searchableSelectPopoverPadding)
                    }
                }
                .frame(maxHeight: LayoutMetrics.searchableSelectResultsHeight)
                .onChange(of: highlightedValue) { _, value in
                    guard scrollsToHighlightedValue, let value else { return }
                    scrollsToHighlightedValue = false
                    withAnimation {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
        .frame(width: LayoutMetrics.searchableSelectWidth)
        .onAppear {
            scrollsToHighlightedValue = true
            highlightedValue = filteredOptions.contains { $0.value == selection }
                ? selection
                : filteredOptions.first?.value
            isSearchFocused = true
        }
        .onChange(of: query) {
            scrollsToHighlightedValue = true
            highlightedValue = filteredOptions.first?.value
        }
        .onMoveCommand { direction in
            moveHighlight(direction)
        }
        .onExitCommand {
            close()
        }
    }

    private func optionRow(_ option: SearchableSelectOption<Value>) -> some View {
        let isHighlighted = highlightedValue == option.value

        return Button {
            selection = option.value
            close()
        } label: {
            HStack(spacing: Spacing.searchableSelectGap) {
                Image(systemName: option.systemImage ?? "circle")
                    .opacity(option.systemImage == nil ? 0 : 1)
                    .accessibilityHidden(true)
                Text(option.title)
                    .lineLimit(1)
                Spacer()
                if selection == option.value {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .font(Typography.fieldValue)
            .foregroundStyle(isHighlighted ? DesignColor.selectedContentForeground : Color.primary)
            .padding(Spacing.searchableSelectPadding)
            .background(
                isHighlighted ? Color.accentColor : Color.clear,
                in: RoundedRectangle(cornerRadius: Spacing.badgeCornerRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(selection == option.value ? "Selected" : "")
        .onHover { isHovering in
            if isHovering {
                scrollsToHighlightedValue = false
                highlightedValue = option.value
            }
        }
    }

    private func moveHighlight(_ direction: MoveCommandDirection) {
        guard direction == .up || direction == .down, !filteredOptions.isEmpty else { return }

        let currentIndex = highlightedValue.flatMap { highlighted in
            filteredOptions.firstIndex { $0.value == highlighted }
        }
        let nextIndex: Int
        if direction == .down {
            nextIndex = min((currentIndex ?? -1) + 1, filteredOptions.count - 1)
        } else {
            nextIndex = max((currentIndex ?? filteredOptions.count) - 1, 0)
        }
        scrollsToHighlightedValue = true
        highlightedValue = filteredOptions[nextIndex].value
    }

    private func selectHighlightedOption() {
        guard let highlightedValue else { return }
        selection = highlightedValue
        close()
    }
}
