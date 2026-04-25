# Accessibility Conformance Statement

**Product**: Prizm (macOS)
**Version**: 1.3.0
**Date**: 2026-04-10
**Standard**: EN 301 549 v3.2.1 / WCAG 2.1 Level AA
**Format**: Based on VPAT 2.4 Rev (Voluntary Product Accessibility Template)

---

## Summary

Prizm is a native macOS SwiftUI application. It inherits platform accessibility features (VoiceOver, keyboard navigation, focus rings, Dynamic Type) from SwiftUI and AppKit. This document reports conformance against WCAG 2.1 Level A and Level AA success criteria as mapped to native software by EN 301 549 Chapter 11.

---

## WCAG 2.1 Level A

| Criterion | Status | Remarks |
|---|---|---|
| 1.1.1 Non-text Content | Supports | All icon-only buttons have `accessibilityLabel`. Decorative images are hidden via `accessibilityHidden(true)`. |
| 1.2.1 Audio-only and Video-only | Not Applicable | No audio or video content. |
| 1.2.2 Captions | Not Applicable | No audio or video content. |
| 1.2.3 Audio Description or Media Alternative | Not Applicable | No audio or video content. |
| 1.3.1 Info and Relationships | Supports | Section headers use `.isHeader` trait. Form fields use native SwiftUI controls with labels. |
| 1.3.2 Meaningful Sequence | Supports | Reading order follows visual layout via SwiftUI's declarative view hierarchy. |
| 1.3.3 Sensory Characteristics | Supports | Instructions do not rely solely on shape, size, or visual location. |
| 1.4.1 Use of Color | Supports | Color is not the sole means of conveying information. Error states include text labels alongside colour indicators. |
| 1.4.2 Audio Control | Not Applicable | No audio playback. |
| 2.1.1 Keyboard | Partially Supports | All major actions have keyboard shortcuts. Drag-and-drop folder operations do not have a keyboard-only alternative. |
| 2.1.2 No Keyboard Trap | Supports | No keyboard traps. Standard macOS focus behaviour applies. |
| 2.1.4 Character Key Shortcuts | Not Applicable | No single-character key shortcuts. All shortcuts use modifier keys. |
| 2.2.1 Timing Adjustable | Not Applicable | No time limits on user actions. Auto-lock is a security feature, not a content timeout. |
| 2.2.2 Pause, Stop, Hide | Not Applicable | No auto-updating or moving content. |
| 2.3.1 Three Flashes or Below Threshold | Supports | No flashing content. All animations respect the macOS Reduce Motion preference. |
| 2.4.1 Bypass Blocks | Supports | Three-pane NavigationSplitView allows direct navigation to sidebar, content, or detail. |
| 2.4.2 Page Titled | Supports | Window title reflects the application name. |
| 2.4.3 Focus Order | Supports | Focus order follows the logical reading order of the three-pane layout. |
| 2.4.4 Link Purpose (In Context) | Supports | The "Open in browser" link includes the field label for context. |
| 2.5.1 Pointer Gestures | Supports | No multi-point or path-based gestures required. |
| 2.5.2 Pointer Cancellation | Supports | Standard macOS button behaviour (activation on mouse-up). |
| 2.5.3 Label in Name | Supports | Accessible names match visible text labels. |
| 2.5.4 Motion Actuation | Not Applicable | No motion-based input. |
| 3.1.1 Language of Page | Supports | App language is determined by macOS system language settings. |
| 3.2.1 On Focus | Supports | No context changes on focus. |
| 3.2.2 On Input | Supports | No unexpected context changes on input. Search filtering is expected behaviour. |
| 3.3.1 Error Identification | Supports | Errors are identified in text. VoiceOver announcements are posted for error banners. |
| 3.3.2 Labels or Instructions | Supports | All form fields have visible labels. |
| 4.1.1 Parsing | Not Applicable | Not applicable to native applications. |
| 4.1.2 Name, Role, Value | Supports | All interactive controls expose name, role, and value to the accessibility API. Stateful controls (favorite star) expose current value. |

## WCAG 2.1 Level AA

| Criterion | Status | Remarks |
|---|---|---|
| 1.3.4 Orientation | Supports | App adapts to window resizing. No fixed orientation. |
| 1.3.5 Identify Input Purpose | Supports | Login fields use standard text field types. |
| 1.4.3 Contrast (Minimum) | Supports | Uses macOS system colours and semantic styles (`.primary`, `.secondary`). Custom opacity values on banners and borders have been raised to meet 3:1 non-text contrast. Increase Contrast preference further raises opacity values. |
| 1.4.4 Resize Text | Supports | SwiftUI semantic fonts respect the macOS text size accessibility setting. |
| 1.4.5 Images of Text | Supports | No images of text. All text is rendered as native text. |
| 1.4.10 Reflow | Supports | Three-pane layout reflows with window resizing. No horizontal scrolling required. |
| 1.4.11 Non-text Contrast | Supports | Icon buttons use system accent colour against system backgrounds. Custom opacity values on borders and indicators meet 3:1 non-text contrast. Increase Contrast preference raises values further. |
| 1.4.12 Text Spacing | Supports | SwiftUI respects system text spacing preferences. |
| 1.4.13 Content on Hover or Focus | Supports | Hover-revealed actions (copy, open, save) do not obscure other content and are dismissible. |
| 2.4.5 Multiple Ways | Supports | Items accessible via sidebar navigation, search (⌘F), and keyboard shortcuts. |
| 2.4.6 Headings and Labels | Supports | Section headers have `.isHeader` trait. All form fields have descriptive labels. |
| 2.4.7 Focus Visible | Supports | macOS provides default focus rings on all focusable controls. |
| 3.2.3 Consistent Navigation | Supports | Sidebar navigation is consistent across all views. |
| 3.2.4 Consistent Identification | Supports | Same actions use same labels throughout (e.g. "Copy", "Reveal", "Delete"). |
| 3.3.3 Error Suggestion | Supports | Error messages include corrective suggestions where an actionable fix is known (e.g. "Check your network connection", "Make sure to include https://"). |
| 3.3.4 Error Prevention (Legal, Financial, Data) | Supports | Destructive actions (delete, permanent delete) require confirmation dialogs. |
| 4.1.3 Status Messages | Supports | Error banners and sync status changes are announced to VoiceOver via `AccessibilityNotification.Announcement`. |

---

## Login Screen — Server Picker

The server-type picker (`Picker` with `.segmented` style) is annotated with:
- `accessibilityIdentifier`: `login.serverTypePicker`
- `accessibilityLabel`: `"Server"` (replaces the default empty label from the segmented style)
- `accessibilityValue`: the current selection label ("Bitwarden Cloud (US)", "Bitwarden Cloud (EU)", or "Self-hosted")

VoiceOver announces the control as *"Server, Bitwarden Cloud (US), segmented control, 1 of 3"* on first focus
and reads the new value when the selection changes.

## New-Device OTP Screen (`NewDeviceOTPView`)

| Element | Identifier | Label |
|---|---|---|
| OTP text field | `login.newDeviceOtpField` | "Verification code" |
| Sign In button | *(inherited from `login.signIn` pattern)* | "Sign In" |
| Resend button | `login.resendOtpButton` | "Resend code" |
| Cancel button | `login.cancelOtpButton` | "Cancel" |
| Error label | `login.otpErrorMessage` | *(dynamic error text)* |

The header "Check your email" has the `.isHeader` accessibility trait so VoiceOver reads it with
heading emphasis on first appearance.

All error messages (OTP invalid, resend failure) are posted as `AccessibilityNotification.Announcement`
so VoiceOver announces them immediately without requiring focus to move to the error label.

## Known Gaps

1. **Drag-and-drop lacks keyboard alternative** (2.1.1) — Folder drag-and-drop operations cannot be performed via keyboard alone. Items can be moved to folders via the edit form as a workaround.

---

## Testing

Accessibility was tested with:
- VoiceOver on macOS 26
- Keyboard-only navigation
- Xcode Accessibility Inspector

---

## Contact

To report an accessibility issue, [open an issue](https://github.com/b0x42/prizm/issues) with the "accessibility" label.
