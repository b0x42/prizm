## 1. Option Key Monitor

- [x] 1.1 Create `OptionKeyMonitor` (`@Observable`) that uses `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)` to publish a `Bool` indicating whether the Option key is currently held; remove the monitor on deinit to prevent leaks
- [x] 1.2 Inject `OptionKeyMonitor` into the SwiftUI environment from the app entry point

## 2. MaskedFieldView Integration

- [x] 2.1 Read the `OptionKeyMonitor` from the environment in `MaskedFieldView` and show plaintext when `isOptionHeld` is true, regardless of `isRevealed` state

## 3. Testing

- [x] 3.1 Add unit tests for `OptionKeyMonitor` state transitions
- [x] 3.2 Add unit tests verifying `MaskedFieldView` display logic with peek active/inactive combined with toggle revealed/hidden, including that releasing Option does not alter toggle state
