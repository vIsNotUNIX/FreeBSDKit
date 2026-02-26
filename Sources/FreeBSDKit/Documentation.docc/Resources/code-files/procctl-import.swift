import Procctl
import Glibc

// Procctl provides process control:
// - ASLR control
// - Stack gap randomization
// - Core dump settings
// - Process descriptors (pdfork)
// - Trapcap (trap capability violations)
