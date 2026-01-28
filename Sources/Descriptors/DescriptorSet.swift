/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import Glibc
import Foundation
import FreeBSDKit

public struct DescriptorSet: Sendable {
    private var descriptors: [OpaqueDescriptorRef] = []

    public init(_ desc: [OpaqueDescriptorRef]) {
        self.descriptors = desc
    }

    public
    mutating func insert(_ desc: consuming some Descriptor, kind: DescriptorKind,) {
        descriptors.append(
            OpaqueDescriptorRef(desc.take(), kind: kind)
        )
    }

    public func all(ofKind kind: DescriptorKind) -> [OpaqueDescriptorRef] {
        descriptors.filter { $0.kind == kind }
    }

    public func first(ofKind kind: DescriptorKind) -> OpaqueDescriptorRef? {
        descriptors.first { $0.kind == kind }
    }
}

extension DescriptorSet: Sequence {
    public struct Iterator: Swift.IteratorProtocol {
        private let descriptors: [OpaqueDescriptorRef]
        private var index = 0

        init(_ descriptors: [OpaqueDescriptorRef]) {
            self.descriptors = descriptors
        }

        public mutating func next() -> OpaqueDescriptorRef? {
            guard index < descriptors.count else { return nil }
            defer { index += 1 }
            return descriptors[index]
        }
    }

    public func makeIterator() -> Iterator {
        Iterator(descriptors)
    }
}