import Audit

let pipe = try Audit.Pipe()

// Read audit records in a loop
while let rawRecord = try pipe.readRawRecord() {
    // Parse the raw record
    let record = try Audit.Record(data: rawRecord)

    print("Event: \(record.eventType)")
    print("Time: \(record.timestamp)")

    // Process individual tokens
    for token in record.tokens {
        switch token {
        case .subject(let subject):
            print("  Subject: uid=\(subject.uid), pid=\(subject.pid)")
        case .path(let path):
            print("  Path: \(path)")
        case .return(let ret):
            print("  Return: \(ret.value) (error: \(ret.error))")
        default:
            break
        }
    }
    print("---")
}
