import AppKit
import Observation

@Observable
final class OptionKeyMonitor {
    private(set) var isOptionHeld = false
    private var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.isOptionHeld = event.modifierFlags.contains(.option)
            return event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
