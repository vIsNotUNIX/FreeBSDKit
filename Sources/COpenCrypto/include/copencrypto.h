/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef COPENCRYPTO_H
#define COPENCRYPTO_H

#include <sys/types.h>
#include <sys/ioctl.h>
#include <crypto/cryptodev.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

/* Algorithm constants - re-export for Swift */
#define COPENCRYPTO_AES_CBC         CRYPTO_AES_CBC
#define COPENCRYPTO_AES_XTS         CRYPTO_AES_XTS
#define COPENCRYPTO_AES_CTR         CRYPTO_AES_ICM
#define COPENCRYPTO_AES_GCM         CRYPTO_AES_NIST_GCM_16
#define COPENCRYPTO_AES_CCM         CRYPTO_AES_CCM_16
#define COPENCRYPTO_CHACHA20        CRYPTO_CHACHA20
#define COPENCRYPTO_CHACHA20_POLY1305 CRYPTO_CHACHA20_POLY1305

#define COPENCRYPTO_SHA1            CRYPTO_SHA1
#define COPENCRYPTO_SHA2_224        CRYPTO_SHA2_224
#define COPENCRYPTO_SHA2_256        CRYPTO_SHA2_256
#define COPENCRYPTO_SHA2_384        CRYPTO_SHA2_384
#define COPENCRYPTO_SHA2_512        CRYPTO_SHA2_512
#define COPENCRYPTO_BLAKE2B         CRYPTO_BLAKE2B
#define COPENCRYPTO_BLAKE2S         CRYPTO_BLAKE2S

#define COPENCRYPTO_SHA1_HMAC       CRYPTO_SHA1_HMAC
#define COPENCRYPTO_SHA2_256_HMAC   CRYPTO_SHA2_256_HMAC
#define COPENCRYPTO_SHA2_384_HMAC   CRYPTO_SHA2_384_HMAC
#define COPENCRYPTO_SHA2_512_HMAC   CRYPTO_SHA2_512_HMAC
#define COPENCRYPTO_POLY1305        CRYPTO_POLY1305

/* Hash lengths */
#define COPENCRYPTO_SHA1_LEN        SHA1_HASH_LEN
#define COPENCRYPTO_SHA2_224_LEN    SHA2_224_HASH_LEN
#define COPENCRYPTO_SHA2_256_LEN    SHA2_256_HASH_LEN
#define COPENCRYPTO_SHA2_384_LEN    SHA2_384_HASH_LEN
#define COPENCRYPTO_SHA2_512_LEN    SHA2_512_HASH_LEN
#define COPENCRYPTO_POLY1305_LEN    POLY1305_HASH_LEN

/* Block sizes */
#define COPENCRYPTO_AES_BLOCK_LEN   16

/* Operations */
#define COPENCRYPTO_ENCRYPT         COP_ENCRYPT
#define COPENCRYPTO_DECRYPT         COP_DECRYPT

/* Open /dev/crypto */
static inline int copencrypto_open(void) {
    return open("/dev/crypto", O_RDWR | O_CLOEXEC);
}

/* Close the crypto device */
static inline int copencrypto_close(int fd) {
    return close(fd);
}

/* Create a session for cipher operations */
static inline int copencrypto_create_session(
    int fd,
    uint32_t cipher,
    uint32_t mac,
    const void *key,
    uint32_t keylen,
    const void *mackey,
    uint32_t mackeylen,
    uint32_t *session_id
) {
    struct session2_op sop;
    memset(&sop, 0, sizeof(sop));

    sop.cipher = cipher;
    sop.mac = mac;
    sop.keylen = keylen;
    sop.key = key;
    sop.mackeylen = mackeylen;
    sop.mackey = mackey;

    if (ioctl(fd, CIOCGSESSION2, &sop) < 0) {
        return -1;
    }

    *session_id = sop.ses;
    return 0;
}

/* Create a simple cipher session */
static inline int copencrypto_cipher_session(
    int fd,
    uint32_t cipher,
    const void *key,
    uint32_t keylen,
    uint32_t *session_id
) {
    return copencrypto_create_session(fd, cipher, 0, key, keylen, NULL, 0, session_id);
}

/* Create a simple hash session */
static inline int copencrypto_hash_session(
    int fd,
    uint32_t mac,
    const void *key,
    uint32_t keylen,
    uint32_t *session_id
) {
    return copencrypto_create_session(fd, 0, mac, NULL, 0, key, keylen, session_id);
}

/* Destroy a session */
static inline int copencrypto_destroy_session(int fd, uint32_t session_id) {
    return ioctl(fd, CIOCFSESSION, &session_id);
}

/* Perform cipher operation */
static inline int copencrypto_cipher(
    int fd,
    uint32_t session_id,
    int op,                 /* COPENCRYPTO_ENCRYPT or COPENCRYPTO_DECRYPT */
    const void *iv,
    const void *src,
    void *dst,
    uint32_t len
) {
    struct crypt_op cop;
    memset(&cop, 0, sizeof(cop));

    cop.ses = session_id;
    cop.op = (uint16_t)op;
    cop.len = len;
    cop.src = src;
    cop.dst = dst;
    cop.iv = iv;

    return ioctl(fd, CIOCCRYPT, &cop);
}

/* Perform hash/MAC operation */
static inline int copencrypto_hash(
    int fd,
    uint32_t session_id,
    const void *src,
    uint32_t len,
    void *mac_out
) {
    struct crypt_op cop;
    memset(&cop, 0, sizeof(cop));

    cop.ses = session_id;
    cop.op = 0;  /* Not used for hash-only */
    cop.len = len;
    cop.src = src;
    cop.dst = NULL;
    cop.mac = mac_out;

    return ioctl(fd, CIOCCRYPT, &cop);
}

/* Perform AEAD operation (encrypt + authenticate) */
static inline int copencrypto_aead(
    int fd,
    uint32_t session_id,
    int op,
    const void *iv,
    uint32_t ivlen,
    const void *aad,
    uint32_t aadlen,
    const void *src,
    void *dst,
    uint32_t len,
    void *tag,
    uint32_t taglen
) {
    struct crypt_aead caead;
    memset(&caead, 0, sizeof(caead));

    caead.ses = session_id;
    caead.op = (uint16_t)op;
    caead.flags = 0;
    caead.len = len;
    caead.aadlen = aadlen;
    caead.ivlen = ivlen;
    caead.src = src;
    caead.dst = dst;
    caead.aad = aad;
    caead.tag = tag;
    caead.iv = iv;

    return ioctl(fd, CIOCCRYPTAEAD, &caead);
}

/* Find crypto device by name or capability */
static inline int copencrypto_find_device(
    int fd,
    int cipher,
    int mac,
    int *crid
) {
    struct crypt_find_op fop;
    memset(&fop, 0, sizeof(fop));

    fop.crid = -1;  /* Any driver */

    if (ioctl(fd, CIOCFINDDEV, &fop) < 0) {
        return -1;
    }

    *crid = fop.crid;
    return 0;
}

#endif /* COPENCRYPTO_H */
