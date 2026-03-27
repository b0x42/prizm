## 1. CardBackground — remove shadow, reduce corner radius

- [x] 1.1 Remove `.shadow()` from `CardBackground` ViewModifier
- [x] 1.2 Change corner radius from 12 to 10

## 2. FieldRowView — horizontal layout

- [x] 2.1 Add `isMultiLine: Bool = false` parameter to `FieldRowView`
- [x] 2.2 When `isMultiLine` is false and `isMasked` is false, render label left / value right on the same line
- [x] 2.3 When `isMultiLine` is true, keep the existing stacked layout (label above value)
- [x] 2.4 Update all Notes field callers to pass `isMultiLine: true`
