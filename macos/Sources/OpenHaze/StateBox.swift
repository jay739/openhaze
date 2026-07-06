import Combine

/// Stand-in for SwiftUI's @State. This machine's Command Line Tools lack the
/// SwiftUIMacros plugin that @State expands through in the macOS 26 SDK, so
/// per-view state lives in a plain ObservableObject held by @StateObject
/// (which is not macro-based) instead.
final class StateBox<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
