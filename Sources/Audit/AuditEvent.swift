/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CAudit
import Glibc

// MARK: - Event Information

extension Audit {
    /// Information about an audit event.
    public struct EventInfo {
        /// The event number.
        public let number: EventNumber
        /// The event name (e.g., "AUE_OPEN").
        public let name: String
        /// Human-readable description.
        public let description: String
        /// The event class mask.
        public let eventClass: EventClass

        /// Creates EventInfo from the C structure.
        internal init?(from entry: UnsafeMutablePointer<au_event_ent>?) {
            guard let entry = entry else { return nil }
            self.number = entry.pointee.ae_number
            self.name = entry.pointee.ae_name.map { String(cString: $0) } ?? ""
            self.description = entry.pointee.ae_desc.map { String(cString: $0) } ?? ""
            self.eventClass = entry.pointee.ae_class
        }
    }

    /// Looks up an event by its number.
    ///
    /// - Parameter number: The event number to look up.
    /// - Returns: Event information, or `nil` if not found.
    public static func getEvent(number: EventNumber) -> EventInfo? {
        EventInfo(from: caudit_getauevnum(number))
    }

    /// Looks up an event by its name.
    ///
    /// - Parameter name: The event name to look up (e.g., "AUE_OPEN").
    /// - Returns: Event information, or `nil` if not found.
    public static func getEvent(name: String) -> EventInfo? {
        name.withCString { cName in
            EventInfo(from: caudit_getauevnam(cName))
        }
    }

    /// Iterates over all defined audit events.
    ///
    /// - Parameter body: A closure called for each event.
    public static func forEachEvent(_ body: (EventInfo) -> Void) {
        caudit_setauevent()
        defer { caudit_endauevent() }

        while let entry = caudit_getauevent() {
            if let info = EventInfo(from: entry) {
                body(info)
            }
        }
    }

    /// Returns all defined audit events.
    ///
    /// - Returns: An array of all event information.
    public static var allEvents: [EventInfo] {
        var events: [EventInfo] = []
        forEachEvent { events.append($0) }
        return events
    }
}

// MARK: - Class Information

extension Audit {
    /// Information about an audit class.
    public struct ClassInfo {
        /// The class name (e.g., "fr" for file read).
        public let name: String
        /// The class bitmask.
        public let classMask: EventClass
        /// Human-readable description.
        public let description: String

        /// Creates ClassInfo from the C structure.
        internal init?(from entry: UnsafeMutablePointer<au_class_ent>?) {
            guard let entry = entry else { return nil }
            self.name = entry.pointee.ac_name.map { String(cString: $0) } ?? ""
            self.classMask = entry.pointee.ac_class
            self.description = entry.pointee.ac_desc.map { String(cString: $0) } ?? ""
        }
    }

    /// Looks up a class by its mask value.
    ///
    /// - Parameter classMask: The class mask to look up.
    /// - Returns: Class information, or `nil` if not found.
    public static func getClass(mask: EventClass) -> ClassInfo? {
        ClassInfo(from: caudit_getauclassnum(mask))
    }

    /// Looks up a class by its name.
    ///
    /// - Parameter name: The class name to look up (e.g., "fr").
    /// - Returns: Class information, or `nil` if not found.
    public static func getClass(name: String) -> ClassInfo? {
        name.withCString { cName in
            ClassInfo(from: caudit_getauclassnam(cName))
        }
    }

    /// Iterates over all defined audit classes.
    ///
    /// - Parameter body: A closure called for each class.
    public static func forEachClass(_ body: (ClassInfo) -> Void) {
        caudit_setauclass()
        defer { caudit_endauclass() }

        while let entry = caudit_getauclassent() {
            if let info = ClassInfo(from: entry) {
                body(info)
            }
        }
    }

    /// Returns all defined audit classes.
    ///
    /// - Returns: An array of all class information.
    public static var allClasses: [ClassInfo] {
        var classes: [ClassInfo] = []
        forEachClass { classes.append($0) }
        return classes
    }
}

// MARK: - Preselection

extension Audit {
    /// Determines if an event would be audited given a mask.
    ///
    /// - Parameters:
    ///   - event: The event number to check.
    ///   - mask: The preselection mask.
    ///   - success: Check against success events (default: true).
    ///   - failure: Check against failure events (default: true).
    /// - Returns: `true` if the event would be audited.
    public static func wouldAudit(
        event: EventNumber,
        mask: Mask,
        success: Bool = true,
        failure: Bool = true
    ) -> Bool {
        var sorf: Int32 = 0
        if success { sorf |= AU_PRS_SUCCESS }
        if failure { sorf |= AU_PRS_FAILURE }

        var cMask = mask.toC()
        return caudit_preselect(event, &cMask, sorf, AU_PRS_REREAD) != 0
    }
}

// MARK: - Common Event Numbers

extension Audit {
    /// Common audit event numbers for user-space events.
    ///
    /// These are defined in audit_uevents.h. Use getEvent(number:) to
    /// look up the full information for any event.
    public enum UserEvent {
        /// User/application audit record (generic).
        public static let other: EventNumber = 32767  // AUE_audit_user
    }
}
