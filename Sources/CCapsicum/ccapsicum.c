#include "ccapsicum.h"

int
ccapsicum_cap_limit(int fd, const cap_rights_t* rights) {
    return cap_rights_limit(fd, rights);
}

cap_rights_t* 
ccapsicum_rights_init(cap_rights_t *rights) {
    return cap_rights_init(rights);
}

cap_rights_t*
ccapsicum_cap_rights_merge(cap_rights_t* rightA, const cap_rights_t* rightB) {
    return cap_rights_merge(rightA, rightB);
}

cap_rights_t*
ccaspsicum_cap_set(cap_rights_t* rights, ccapsicum_right_bridge right) {
    return cap_rights_set(rights, ccapsicum_selector(right));
}

bool
ccapsicum_right_is_set(const cap_rights_t* rights, ccapsicum_right_bridge right) {
    return cap_rights_is_set(rights, ccapsicum_selector(right));
}

void
ccap_rights_clear(cap_rights_t* rights, ccapsicum_right_bridge right) {
    cap_rights_clear(rights, right);
}

bool
ccap_rights_valid(cap_rights_t* rights) {
    return cap_rights_is_valid(rights);
}

bool 
ccap_rights_contains(const cap_rights_t *big, const cap_rights_t *little) {
    return cap_rights_contains(big, little);
}
cap_rights_t* 
ccap_rights_remove(cap_rights_t *dst, const cap_rights_t *src) {
    return cap_rights_remove(dst, src);
}

uint64_t
ccapsicum_selector(ccapsicum_right_bridge r)
{
    switch (r) {
    case CCAP_RIGHT_READ:  return CAP_READ;
    case CCAP_RIGHT_WRITE: return CAP_WRITE;
    case CCAP_RIGHT_SEEK:  return CAP_SEEK;
    }
}