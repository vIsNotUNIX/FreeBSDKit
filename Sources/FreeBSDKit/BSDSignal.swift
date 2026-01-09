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

/// Standard signals for process descriptors.
public enum BSDSignal: Int32 {
    case hangup             = 1
    case interrupt          = 2
    case quit               = 3
    case illegal            = 4
    case trap               = 5
    case abort              = 6
    case bus                = 7
    case floatingPoint      = 8
    case kill               = 9
    case user1              = 10
    case segmentationFault  = 11
    case user2              = 12
    case pipe               = 13
    case alarm              = 14
    case terminate          = 15
    case urgent             = 16
    case stop               = 17
    case ttyStop            = 18
    case continueRun        = 19
    case child              = 20
    case ttin               = 21
    case ttou               = 22
    case io                 = 23
    case xcpu               = 24
    case xfsz               = 25
    case virtualAlarm       = 26
    case profiling          = 27
    case winch              = 28
    case usr1               = 30
    case usr2               = 31
}