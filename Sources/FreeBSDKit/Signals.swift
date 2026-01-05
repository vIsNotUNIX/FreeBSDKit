/// Standard signals for process descriptors.
public enum Signals: Int32 {
    case hangup       = 1
    case interrupt    = 2
    case quit         = 3
    case illegal      = 4
    case trap         = 5
    case abort        = 6
    case bus          = 7
    case floatingPoint = 8
    case kill         = 9
    case user1        = 10
    case segmentationFault = 11
    case user2        = 12
    case pipe         = 13
    case alarm        = 14
    case terminate    = 15
    case urgent       = 16
    case stop         = 17
    case ttyStop      = 18
    case continueRun  = 19
    case child        = 20
    case ttin         = 21
    case ttou         = 22
    case io           = 23
    case xcpu         = 24
    case xfsz         = 25
    case virtualAlarm = 26
    case profiling    = 27
    case winch        = 28
    case usr1         = 30
    case usr2         = 31
}