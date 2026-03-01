/*
 * DProbesMacros - Swift Macro Implementations for DProbes
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DProbesPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DTraceProviderMacro.self,
        ProbeMacro.self,
        ProbeEnabledMacro.self
    ]
}
