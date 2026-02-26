import Rctl

// Rctl provides resource control:
// - Rctl.add() - Add a resource rule
// - Rctl.remove() - Remove a rule
// - Rctl.getRules() - Get active rules
// - Rctl.getUsage() - Get resource usage

// Rule format: subject:subject-id:resource:action=amount
// Example: "user:john:maxproc:deny=100"
