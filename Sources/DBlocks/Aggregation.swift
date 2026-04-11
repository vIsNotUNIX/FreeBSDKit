/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import CDTrace
import Foundation

// `dtrace_aggdata_t` and `dtrace_recdesc_t` come from the system
// `<dtrace.h>` header that the CDTrace shim re-exports.

// MARK: - Aggregation key

/// A single key column in an aggregation row.
///
/// DTrace aggregation keys can be integers or strings depending on
/// what the script's grouping expression evaluated to. The wrapper
/// preserves the underlying type when it can recognize it; anything
/// else falls through as raw bytes.
public enum AggregationKey: Sendable, Equatable {
    case int(Int64)
    case string(String)
    case bytes([UInt8])

    /// String view of the key, suitable for display.
    public var description: String {
        switch self {
        case .int(let v):    return String(v)
        case .string(let s): return s
        case .bytes(let b):  return "<\(b.count) bytes>"
        }
    }
}

// MARK: - Aggregation value

/// The summarized value of an aggregation row.
///
/// Scalar aggregations (`count`, `sum`, `min`, `max`, `avg`, `stddev`)
/// are decoded into `Int64`. Bucketed aggregations (`quantize`,
/// `lquantize`, `llquantize`) are surfaced as raw bytes for now —
/// follow-up work will decode their bucket layouts.
public enum AggregationValue: Sendable, Equatable {
    case count(Int64)
    case sum(Int64)
    case min(Int64)
    case max(Int64)
    case avg(Int64)
    case stddev(Int64)
    /// A `quantize` (power-of-2 histogram) value, as raw bytes. Decode
    /// with libdtrace until typed support lands.
    case quantize(Data)
    /// An `lquantize` (linear histogram) value, as raw bytes.
    case lquantize(Data)
    /// An `llquantize` (log-linear histogram) value, as raw bytes.
    case llquantize(Data)
    /// An aggregation kind we did not recognize, with the raw payload.
    case unknown(action: UInt16, Data)

    /// Convenience: pull a scalar Int64 out of any of the integer-shaped
    /// cases (count/sum/min/max/avg/stddev). Returns `nil` for the
    /// histogram cases.
    public var asInt: Int64? {
        switch self {
        case .count(let v), .sum(let v), .min(let v),
             .max(let v),   .avg(let v), .stddev(let v):
            return v
        default:
            return nil
        }
    }
}

// MARK: - Aggregation record

/// A single aggregation row.
///
/// Roughly equivalent to one line of `printa(@name)` output, but in a
/// form Swift code can introspect: the aggregation's name, the key
/// columns, and the typed value.
public struct AggregationRecord: Sendable, Equatable {
    /// Name of the aggregation, e.g. `"calls"`. Empty for anonymous
    /// aggregations declared with `Count()` and friends.
    public let name: String

    /// Key columns, in the order they appeared in the aggregation
    /// expression's `[…]` brackets.
    public let keys: [AggregationKey]

    /// The summarized value.
    public let value: AggregationValue

    public init(name: String, keys: [AggregationKey], value: AggregationValue) {
        self.name = name
        self.keys = keys
        self.value = value
    }
}

// MARK: - Decoder

extension AggregationRecord {

    /// Decode a single `dtrace_aggdata_t *` into an `AggregationRecord`.
    /// Returns `nil` if the description has no records (which would
    /// indicate a malformed aggregation that we can't usefully report).
    static func decode(from aggdata: UnsafePointer<dtrace_aggdata_t>) -> AggregationRecord? {
        let desc = cdtrace_aggdata_desc(aggdata)
        guard let desc else { return nil }
        let nrecs = Int(cdtrace_aggdesc_nrecs(desc))
        guard nrecs >= 1 else { return nil }

        let name: String
        if let cname = cdtrace_aggdesc_name(desc) {
            name = String(cString: cname)
        } else {
            name = ""
        }

        guard let dataBase = cdtrace_aggdata_data(aggdata) else { return nil }

        // The last record is the aggregation value; everything before
        // it describes the keys.
        var keys: [AggregationKey] = []
        keys.reserveCapacity(nrecs - 1)
        for i in 0..<(nrecs - 1) {
            guard let rec = cdtrace_aggdesc_rec(desc, Int32(i)) else { continue }
            keys.append(decodeKey(rec: rec, dataBase: dataBase))
        }

        let valueRec = cdtrace_aggdesc_rec(desc, Int32(nrecs - 1))!
        let value = decodeValue(rec: valueRec, dataBase: dataBase)

        return AggregationRecord(name: name, keys: keys, value: value)
    }

    private static func decodeKey(
        rec: UnsafePointer<dtrace_recdesc_t>,
        dataBase: UnsafeMutablePointer<CChar>
    ) -> AggregationKey {
        let offset = Int(cdtrace_recdesc_offset(rec))
        let size = Int(cdtrace_recdesc_size(rec))
        let raw = UnsafeRawPointer(dataBase.advanced(by: offset))

        // Heuristic: int-sized scalars (1, 2, 4, 8 bytes) come back as
        // signed integers; anything bigger is treated as a NUL-terminated
        // string until we hit a NUL or run out of bytes; otherwise raw
        // bytes.
        switch size {
        case 8:
            return .int(raw.load(as: Int64.self))
        case 4:
            return .int(Int64(raw.load(as: Int32.self)))
        case 2:
            return .int(Int64(raw.load(as: Int16.self)))
        case 1:
            return .int(Int64(raw.load(as: Int8.self)))
        default:
            // Try string first.
            let buf = UnsafeBufferPointer(
                start: raw.assumingMemoryBound(to: UInt8.self),
                count: size
            )
            if let nul = buf.firstIndex(of: 0) {
                let bytes = Array(buf.prefix(nul))
                if let str = String(bytes: bytes, encoding: .utf8), !str.isEmpty {
                    return .string(str)
                }
            }
            return .bytes(Array(buf))
        }
    }

    private static func decodeValue(
        rec: UnsafePointer<dtrace_recdesc_t>,
        dataBase: UnsafeMutablePointer<CChar>
    ) -> AggregationValue {
        let action = cdtrace_recdesc_action(rec)
        let offset = Int(cdtrace_recdesc_offset(rec))
        let size = Int(cdtrace_recdesc_size(rec))
        let raw = UnsafeRawPointer(dataBase.advanced(by: offset))

        // Scalar aggregations: the kernel stores them as int64 with the
        // sample count tucked alongside. From a consumer perspective the
        // first int64 at the record offset is what `printa` would print,
        // so use that.
        func loadInt() -> Int64 {
            raw.load(as: Int64.self)
        }

        func loadAvg() -> Int64 {
            // The avg/stddev records hold (count, sum, [sum_sq...]).
            // libdtrace's `printa` reports sum/count for avg.
            let count = raw.load(as: Int64.self)
            let sum = raw.load(fromByteOffset: 8, as: Int64.self)
            return count == 0 ? 0 : sum / count
        }

        func loadBytes() -> Data {
            Data(bytes: raw, count: size)
        }

        switch UInt32(action) {
        case UInt32(CDTRACE_AGG_COUNT.rawValue):
            return .count(loadInt())
        case UInt32(CDTRACE_AGG_MIN.rawValue):
            return .min(loadInt())
        case UInt32(CDTRACE_AGG_MAX.rawValue):
            return .max(loadInt())
        case UInt32(CDTRACE_AGG_SUM.rawValue):
            return .sum(loadInt())
        case UInt32(CDTRACE_AGG_AVG.rawValue):
            return .avg(loadAvg())
        case UInt32(CDTRACE_AGG_STDDEV.rawValue):
            // Stddev needs sqrt over a sum-of-squares the kernel
            // accumulates; expose the rolling mean for now and let
            // callers compute the deviation from the raw bytes if
            // needed.
            return .stddev(loadAvg())
        case UInt32(CDTRACE_AGG_QUANTIZE.rawValue):
            return .quantize(loadBytes())
        case UInt32(CDTRACE_AGG_LQUANTIZE.rawValue):
            return .lquantize(loadBytes())
        case UInt32(CDTRACE_AGG_LLQUANTIZE.rawValue):
            return .llquantize(loadBytes())
        default:
            return .unknown(action: action, loadBytes())
        }
    }
}
