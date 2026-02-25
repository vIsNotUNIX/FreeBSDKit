/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CAUDIT_H
#define CAUDIT_H

#include <sys/types.h>
#include <sys/ioccom.h>
#include <bsm/audit.h>
#include <bsm/libbsm.h>
#include <bsm/audit_record.h>
#include <bsm/audit_kevents.h>
#include <bsm/audit_uevents.h>
#include <security/audit/audit_ioctl.h>
#include <errno.h>

// Audit condition constants
#define CAUDIT_AUC_UNSET       AUC_UNSET
#define CAUDIT_AUC_AUDITING    AUC_AUDITING
#define CAUDIT_AUC_NOAUDIT     AUC_NOAUDIT
#define CAUDIT_AUC_DISABLED    AUC_DISABLED

// Audit policy flags
#define CAUDIT_POLICY_CNT      AUDIT_CNT
#define CAUDIT_POLICY_AHLT     AUDIT_AHLT
#define CAUDIT_POLICY_ARGV     AUDIT_ARGV
#define CAUDIT_POLICY_ARGE     AUDIT_ARGE
#define CAUDIT_POLICY_SEQ      AUDIT_SEQ
#define CAUDIT_POLICY_WINDATA  AUDIT_WINDATA
#define CAUDIT_POLICY_USER     AUDIT_USER
#define CAUDIT_POLICY_GROUP    AUDIT_GROUP
#define CAUDIT_POLICY_TRAIL    AUDIT_TRAIL
#define CAUDIT_POLICY_PATH     AUDIT_PATH

// Audit close flags
#define CAUDIT_TO_NO_WRITE     AU_TO_NO_WRITE
#define CAUDIT_TO_WRITE        AU_TO_WRITE

// Auditpipe preselect modes
#define CAUDIT_PRESELECT_MODE_TRAIL  AUDITPIPE_PRESELECT_MODE_TRAIL
#define CAUDIT_PRESELECT_MODE_LOCAL  AUDITPIPE_PRESELECT_MODE_LOCAL

// Token type identifiers (most common ones)
#define CAUDIT_AUT_HEADER32        AUT_HEADER32
#define CAUDIT_AUT_TRAILER         AUT_TRAILER
#define CAUDIT_AUT_SUBJECT32       AUT_SUBJECT32
#define CAUDIT_AUT_RETURN32        AUT_RETURN32
#define CAUDIT_AUT_TEXT            AUT_TEXT
#define CAUDIT_AUT_PATH            AUT_PATH
#define CAUDIT_AUT_ARG32           AUT_ARG32
#define CAUDIT_AUT_ARG64           AUT_ARG64
#define CAUDIT_AUT_EXIT            AUT_EXIT

// Header modifier flags
#define CAUDIT_PAD_NOTATTR         PAD_NOTATTR
#define CAUDIT_PAD_FAILURE         PAD_FAILURE

// Wrapper for au_open to handle Swift calling convention
static inline int caudit_open(void) {
    return au_open();
}

// Wrapper for au_write
static inline int caudit_write(int d, token_t *m) {
    return au_write(d, m);
}

// Wrapper for au_close
static inline int caudit_close(int d, int keep, short event) {
    return au_close(d, keep, event);
}

// Wrapper for getting the current audit state
// Note: au_get_state() is declared but not exported on FreeBSD,
// so we implement using audit_get_cond() instead.
static inline int caudit_get_state(void) {
    int cond = 0;
    if (audit_get_cond(&cond) != 0) {
        return AUC_DISABLED;
    }
    return cond;
}

// Wrapper for audit_submit
static inline int caudit_submit(short au_event, au_id_t auid,
    char status, int reterr, const char *fmt) {
    return audit_submit(au_event, auid, status, reterr, "%s", fmt);
}

// Wrapper for getting audit ID
static inline int caudit_getauid(au_id_t *auid) {
    return getauid(auid);
}

// Wrapper for setting audit ID
static inline int caudit_setauid(const au_id_t *auid) {
    return setauid(auid);
}

// Wrapper for getting audit info
static inline int caudit_getaudit(auditinfo_t *ai) {
    return getaudit(ai);
}

// Wrapper for setting audit info
static inline int caudit_setaudit(const auditinfo_t *ai) {
    return setaudit(ai);
}

// Wrapper for getting extended audit info
static inline int caudit_getaudit_addr(auditinfo_addr_t *aia, int len) {
    return getaudit_addr(aia, len);
}

// Wrapper for setting extended audit info
static inline int caudit_setaudit_addr(const auditinfo_addr_t *aia, int len) {
    return setaudit_addr(aia, len);
}

// Wrapper for auditon
static inline int caudit_auditon(int cmd, void *data, int length) {
    return auditon(cmd, data, length);
}

// Wrapper for getting audit condition
static inline int caudit_get_cond(int *cond) {
    return audit_get_cond(cond);
}

// Wrapper for setting audit condition
static inline int caudit_set_cond(int *cond) {
    return audit_set_cond(cond);
}

// Wrapper for getting audit policy
static inline int caudit_get_policy(int *policy) {
    return audit_get_policy(policy);
}

// Wrapper for setting audit policy
static inline int caudit_set_policy(int *policy) {
    return audit_set_policy(policy);
}

// Wrapper for getting queue control
static inline int caudit_get_qctrl(au_qctrl_t *qctrl, size_t sz) {
    return audit_get_qctrl(qctrl, sz);
}

// Wrapper for setting queue control
static inline int caudit_set_qctrl(au_qctrl_t *qctrl, size_t sz) {
    return audit_set_qctrl(qctrl, sz);
}

// Wrapper for getting audit statistics
static inline int caudit_get_stat(au_stat_t *stats, size_t sz) {
    return audit_get_stat(stats, sz);
}

// Token creation wrappers
static inline token_t *caudit_to_me(void) {
    return au_to_me();
}

static inline token_t *caudit_to_text(const char *text) {
    return au_to_text(text);
}

static inline token_t *caudit_to_path(const char *path) {
    return au_to_path(path);
}

static inline token_t *caudit_to_return32(char status, uint32_t ret) {
    return au_to_return32(status, ret);
}

static inline token_t *caudit_to_return64(char status, uint64_t ret) {
    return au_to_return64(status, ret);
}

static inline token_t *caudit_to_arg32(char n, const char *text, uint32_t v) {
    return au_to_arg32(n, text, v);
}

static inline token_t *caudit_to_arg64(char n, const char *text, uint64_t v) {
    return au_to_arg64(n, text, v);
}

static inline token_t *caudit_to_exit(int retval, int err) {
    return au_to_exit(retval, err);
}

static inline token_t *caudit_to_subject32(au_id_t auid, uid_t euid, gid_t egid,
    uid_t ruid, gid_t rgid, pid_t pid, au_asid_t sid, au_tid_t *tid) {
    return au_to_subject32(auid, euid, egid, ruid, rgid, pid, sid, tid);
}

static inline token_t *caudit_to_opaque(const char *data, uint16_t bytes) {
    return au_to_opaque(data, bytes);
}

// Free token
static inline void caudit_free_token(token_t *tok) {
    au_free_token(tok);
}

// Event lookup wrappers
static inline struct au_event_ent *caudit_getauevnum(au_event_t event_number) {
    return getauevnum(event_number);
}

static inline struct au_event_ent *caudit_getauevnam(const char *name) {
    return getauevnam(name);
}

// Class lookup wrappers
static inline struct au_class_ent *caudit_getauclassnum(au_class_t class_number) {
    return getauclassnum(class_number);
}

static inline struct au_class_ent *caudit_getauclassnam(const char *name) {
    return getauclassnam(name);
}

// Iteration functions
static inline void caudit_setauevent(void) {
    setauevent();
}

static inline void caudit_endauevent(void) {
    endauevent();
}

static inline struct au_event_ent *caudit_getauevent(void) {
    return getauevent();
}

static inline void caudit_setauclass(void) {
    setauclass();
}

static inline void caudit_endauclass(void) {
    endauclass();
}

static inline struct au_class_ent *caudit_getauclassent(void) {
    return getauclassent();
}

// Preselection
static inline int caudit_preselect(au_event_t event, au_mask_t *mask_p,
    int sorf, int flag) {
    return au_preselect(event, mask_p, sorf, flag);
}

// Record parsing (for audit trail reading)
static inline int caudit_read_rec(FILE *fp, u_char **buf) {
    return au_read_rec(fp, buf);
}

static inline int caudit_fetch_tok(tokenstr_t *tok, u_char *buf, int len) {
    return au_fetch_tok(tok, buf, len);
}

// Default audit ID (uid_t)(-1) - not importable by Swift as macro
static const au_id_t CAUDIT_DEFAUDITID = (au_id_t)(-1);
static const au_asid_t CAUDIT_DEFAUDITSID = 0;

// Auditpipe ioctls - expose as functions since macros with complex expressions
// aren't importable by Swift
static inline unsigned long caudit_pipe_get_qlen_cmd(void) {
    return AUDITPIPE_GET_QLEN;
}

static inline unsigned long caudit_pipe_get_qlimit_cmd(void) {
    return AUDITPIPE_GET_QLIMIT;
}

static inline unsigned long caudit_pipe_set_qlimit_cmd(void) {
    return AUDITPIPE_SET_QLIMIT;
}

static inline unsigned long caudit_pipe_get_qlimit_min_cmd(void) {
    return AUDITPIPE_GET_QLIMIT_MIN;
}

static inline unsigned long caudit_pipe_get_qlimit_max_cmd(void) {
    return AUDITPIPE_GET_QLIMIT_MAX;
}

static inline unsigned long caudit_pipe_get_preselect_flags_cmd(void) {
    return AUDITPIPE_GET_PRESELECT_FLAGS;
}

static inline unsigned long caudit_pipe_set_preselect_flags_cmd(void) {
    return AUDITPIPE_SET_PRESELECT_FLAGS;
}

static inline unsigned long caudit_pipe_get_preselect_mode_cmd(void) {
    return AUDITPIPE_GET_PRESELECT_MODE;
}

static inline unsigned long caudit_pipe_set_preselect_mode_cmd(void) {
    return AUDITPIPE_SET_PRESELECT_MODE;
}

static inline unsigned long caudit_pipe_flush_cmd(void) {
    return AUDITPIPE_FLUSH;
}

static inline unsigned long caudit_pipe_get_maxauditdata_cmd(void) {
    return AUDITPIPE_GET_MAXAUDITDATA;
}

static inline unsigned long caudit_pipe_get_inserts_cmd(void) {
    return AUDITPIPE_GET_INSERTS;
}

static inline unsigned long caudit_pipe_get_reads_cmd(void) {
    return AUDITPIPE_GET_READS;
}

static inline unsigned long caudit_pipe_get_drops_cmd(void) {
    return AUDITPIPE_GET_DROPS;
}

static inline unsigned long caudit_pipe_get_truncates_cmd(void) {
    return AUDITPIPE_GET_TRUNCATES;
}

#endif /* CAUDIT_H */
