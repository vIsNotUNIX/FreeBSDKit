import Jails

// JailParameters is a builder for jail configuration
var params = JailParameters()

// Required parameters
params.name = "myjail"              // Unique jail name
params.path = "/jails/myjail"       // Root filesystem path
params.hostname = "myjail.local"    // Hostname inside jail

// Optional: persist after all processes exit
params.persist = true

// Optional: allow raw sockets (for ping, etc.)
params.allowRawSockets = true

// Optional: set the securelevel
params.securelevel = 2
