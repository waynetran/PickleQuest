# Bugs to Remember

## SwiftUI .task / .onAppear Race Condition

**Date**: 2024-02-14
**Symptom**: Tab shows empty data on first visit, works on second visit.

**Root Cause**: `.onAppear` fires synchronously before `.task` (which is async) has a chance to create the viewModel. So on first visit, `.onAppear` guard-returns because viewModel is nil, and `.task` creates the viewModel but never loads data.

**Wrong pattern**:
```swift
.task {
    if viewModel == nil {
        viewModel = SomeViewModel(...)
    }
}
.onAppear {
    guard let vm = viewModel else { return } // nil on first visit!
    Task { await vm.loadData() }
}
```

**Correct pattern**:
```swift
.task {
    if viewModel == nil {
        let vm = SomeViewModel(...)
        viewModel = vm
        await vm.loadData() // initial load
    }
}
.onAppear {
    guard let vm = viewModel else { return }
    Task { await vm.loadData() } // reload on subsequent visits
}
```

**Rule**: When a view needs to (1) create a viewModel once and (2) reload data on every appearance, use `.task` for creation + initial load, and `.onAppear` for subsequent reloads. Never rely on `.onAppear` alone for the first load when the viewModel is created in `.task`.
