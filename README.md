# FreeBSDKit

**FreeBSDKit** is a Swift framework that provides an overlay for FreeBSD system APIs. Its goal is to expose platform-specific functionality in a Swift-friendly way, while staying close to the underlying FreeBSD interfaces.

## Scope

FreeBSDKit aims to:

- Overlay platform-specific portions of the FreeBSD API in Swift.
- Provide safe, idiomatic Swift access to low-level FreeBSD functionality.
- Enable developers to leverage FreeBSD capabilities, like Capsicum, without leaving the Swift ecosystem.


## Targets

FreeBSDKit currently exposes:

### 1. CCapsicum

`CCapsicum` is a C wrapper around the Capsicum macros. It provides low-level access to the FreeBSD Capsicum API in a form that can be called from Swift, handling the platform-specific bridging safely and efficiently.

### 2. Capsicum

`Capsicum` is a Swift package built on top of `CCapsicum`. It offers a Swift-native API to interact with Capsicum, allowing developers to adopt the FreeBSD capability model in Swift projects without dealing directly with C macros or platform-specific details.

