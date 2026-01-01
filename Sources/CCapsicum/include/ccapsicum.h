#pragma once

#include <sys/capsicum.h>
#include <sys/caprights.h>

// MARK: Right Bridge.C MACROs are not callable from Swift, so we bridge.
typedef enum {
    CCAP_RIGHT_READ,
    CCAP_RIGHT_WRITE,
    CCAP_RIGHT_SEEK,
} ccapsicum_right_bridge;


// MARK: Bridging functions.
uint64_t inline
ccapsicum_selector(ccapsicum_right_bridge r);

// MARK: Cap Rights Functions
inline int 
ccapsicum_cap_limit(int fd, const cap_rights_t* rights);

inline cap_rights_t*
ccapsicum_rights_init(cap_rights_t *rights);

inline cap_rights_t*
ccapsicum_cap_rights_merge(cap_rights_t* rightA, const cap_rights_t* rightB);

inline cap_rights_t*
ccaspsicum_cap_set(cap_rights_t* right, ccapsicum_right_bridge cap);

inline bool
ccapsicum_right_is_set(const cap_rights_t* rights, ccapsicum_right_bridge right);

inline bool
ccap_rights_valid(cap_rights_t* rights);

inline void
ccap_rights_clear(cap_rights_t* rights, ccapsicum_right_bridge right);

inline bool
ccap_rights_contains(const cap_rights_t *big, const cap_rights_t *little);

inline cap_rights_t*
ccap_rights_remove(cap_rights_t *dst, const cap_rights_t *src);