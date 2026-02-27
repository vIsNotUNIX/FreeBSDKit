# ``FreeBSDKit``

A comprehensive Swift framework for FreeBSD system programming.

@Metadata {
    @DisplayName("FreeBSDKit")
    @PageImage(purpose: icon, source: "freebsd-icon", alt: "FreeBSD icon")
}

## Overview

FreeBSDKit provides idiomatic Swift APIs for FreeBSD-specific system features including:

- **Capsicum** - Capability-based security and sandboxing
- **Descriptors** - Type-safe file, socket, and process descriptors
- **Jails** - FreeBSD jail creation and management
- **FPC** - FreeBSD Privilege-separated Communication
- **MAC Labels** - Mandatory Access Control labels
- **Casper** - Capability-mode helper services
- **Audit** - BSM audit event monitoring
- **Resource Controls** - CPU sets, resource limits, and process control
- **DTrace** - Dynamic tracing with fluent script builder

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Tutorials/FreeBSDKitByExample>

### Core Modules

- ``BSDError``
- ``ExtendedAttribute``

### Security

- <doc:CapsicumOverview>
- <doc:JailsOverview>
- <doc:MACLabelsOverview>

### Inter-Process Communication

- <doc:FPCOverview>
- <doc:DescriptorPassing>

### System Features

- <doc:AuditOverview>
- <doc:ResourceControlsOverview>
