# FreeBSDKit

**FreeBSDKit** is a Swift framework that provides a structured, Swift-native overlay for **FreeBSD system APIs**.  
Its goal is to expose FreeBSD-specific functionality in a way that is:

- idiomatic to Swift
- explicit about ownership and safety
- faithful to the underlying FreeBSD semantics

FreeBSDKit is *not* a portability layer. It intentionally embraces FreeBSD’s unique features and design, making them accessible to Swift developers without forcing them down to C.

FreeBSDKit aims to:

- Provide Swift overlays for **platform-specific FreeBSD APIs**
- Preserve the **semantic intent** of the underlying system interfaces
- Make low-level functionality usable **without unsafe C glue**
- Model **ownership, borrowing, and capabilities** explicitly in the type system
- Enable modern Swift code to leverage FreeBSD features such as **Capsicum**, **jails**, and **descriptors**

## Targets

### 1. **FreeBSDKit** (Core)

The core target defines **shared protocols and foundational abstractions** used throughout the framework.

This includes:

- Common protocol definitions
- Ownership-aware abstractions
- Low-level utility types shared across modules

Notably, this target defines concepts such as:

- Trivial BSD value representations
- Ownership-bearing resource interfaces
- Common conventions for exposing raw BSD types safely

---

### 2. **Descriptors**

The `Descriptors` target defines the **descriptor abstraction hierarchy**.

It provides protocol definitions for:

- Descriptor-like kernel objects
- Ownership-bearing resources (e.g. file descriptors, jail descriptors)
- Borrowed vs owning semantics

This module focuses purely on *what a descriptor is*, not *what it does*.

---

### 3. **Capabilities**

The `Capabilities` target defines:

- The **Capability protocol**
- Concrete capability types

This module models Capsicum concepts at the *type level*, allowing Swift code to reason about:

- What a resource is allowed to do
- How rights are constructed and combined
- How capabilities are passed to kernel APIs

---

### 4. **CCapsicum**

`CCapsicum` is a **C shim target**.

Its sole responsibility is to expose Capsicum APIs that cannot be called directly from Swift, such as:

- C macros
- Inline functions
- Preprocessor-based constants

---

### 5. **Capsicum**

The `Capsicum` target is the **Swift-native interface** to FreeBSD’s Capsicum capability framework.

Built on top of `CCapsicum`, it provides:

- Swift representations of Capsicum rights
- Tools for entering capability mode
- Safe APIs for limiting descriptors
- High-level capability manipulation utilities

This is the target most users will interact with when adopting Capsicum in Swift.

---

## Experimental / In-Progress Modules

The following modules compile but are **experimental**, **incomplete**, or **not yet fully tested**:

- **FreeBSDKit (catch-all)**  
  Early or transitional APIs that do not yet have a clear home.

- **CProcessDescriptors**  
  A wrapper around the FreeBSD process descriptor APIs.

- **Descriptors (extended)**  
  Ongoing work to refine descriptor semantics and hierarchy.

- **Capabilities (extended)**  
  Additional capability types and integrations under active development.

Expect APIs in these modules to change.

---

## Future Work

- **Foundation integration**  
  Swift already provides cross-platform types such as `FileHandle`.  
  On FreeBSD, these expose raw file descriptors that could be extended to support Capsicum capabilities.

  Contributions adding Capsicum-aware extensions to these standard types would be extremely valuable.

- **Testing & validation**
  - Capability-mode test harnesses
  - Jail-based tests
  - Descriptor lifecycle validation

- **Additional FreeBSD subsystems**
  - Jails
  - kqueue
  - Process descriptors

---

## Non-Goals

FreeBSDKit does **not** aim to:

- Be portable across non-FreeBSD platforms

This project embraces FreeBSD’s identity rather than abstracting it away.