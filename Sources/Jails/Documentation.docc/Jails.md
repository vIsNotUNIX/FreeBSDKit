# Using the FreeBSD Jails Swift API

This document shows **concrete examples** of how to call the provided Swift
jail APIs to create, update, and query jails using `jail_set(2)` and
`jail_get(2)`.

All examples assume:
- FreeBSD
- Appropriate privileges (typically root)
- The `CJails` module is available
- The module containing these types is named `Jails`

Relevant manual pages:
- `jail_set(2)`
- `jail_get(2)`
- `jail(8)`

---

## Imports

```swift
import CJails
import Jails
import Glibc
