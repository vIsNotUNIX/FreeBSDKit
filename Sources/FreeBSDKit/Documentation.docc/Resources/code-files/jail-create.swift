import Jails

var params = JailParameters()
params.name = "myjail"
params.path = "/jails/myjail"
params.hostname = "myjail.local"

// Create the jail
// Returns the jail ID (JID)
do {
    let jid = try Jail.create(parameters: params)
    print("Created jail with JID: \(jid)")
} catch let error as JailError {
    print("Failed to create jail: \(error)")
}
