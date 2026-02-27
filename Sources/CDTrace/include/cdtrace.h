/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CDTRACE_H
#define CDTRACE_H

#include <dtrace.h>
#include <stdint.h>
#include <libproc.h>

/*
 * CDTrace - C bridge for libdtrace
 *
 * This module exposes libdtrace functions to Swift. Since Swift cannot
 * import inline functions or macros directly, we provide thin wrappers.
 */

/* Open flags - mirror DTRACE_O_* */
typedef enum {
    CDTRACE_O_NONE   = 0,
    CDTRACE_O_NODEV  = DTRACE_O_NODEV,   /* do not open dtrace(7D) device */
    CDTRACE_O_NOSYS  = DTRACE_O_NOSYS,   /* do not load /system/object modules */
    CDTRACE_O_LP64   = DTRACE_O_LP64,    /* force D compiler to be LP64 */
    CDTRACE_O_ILP32  = DTRACE_O_ILP32    /* force D compiler to be ILP32 */
} cdtrace_open_flag_t;

/* Compile flags - mirror DTRACE_C_* */
typedef enum {
    CDTRACE_C_NONE   = 0,
    CDTRACE_C_DIFV   = DTRACE_C_DIFV,    /* DIF verbose mode */
    CDTRACE_C_EMPTY  = DTRACE_C_EMPTY,   /* permit empty D source */
    CDTRACE_C_ZDEFS  = DTRACE_C_ZDEFS,   /* permit zero probe matches */
    CDTRACE_C_PSPEC  = DTRACE_C_PSPEC,   /* interpret as probes */
    CDTRACE_C_NOLIBS = DTRACE_C_NOLIBS   /* do not process D system libraries */
} cdtrace_compile_flag_t;

/* Probe specification types */
typedef enum {
    CDTRACE_PROBESPEC_NONE   = DTRACE_PROBESPEC_NONE,
    CDTRACE_PROBESPEC_PROVIDER = DTRACE_PROBESPEC_PROVIDER,
    CDTRACE_PROBESPEC_MOD    = DTRACE_PROBESPEC_MOD,
    CDTRACE_PROBESPEC_FUNC   = DTRACE_PROBESPEC_FUNC,
    CDTRACE_PROBESPEC_NAME   = DTRACE_PROBESPEC_NAME
} cdtrace_probespec_t;

/* Work status - mirror dtrace_workstatus_t */
typedef enum {
    CDTRACE_WORKSTATUS_ERROR = DTRACE_WORKSTATUS_ERROR,
    CDTRACE_WORKSTATUS_OKAY  = DTRACE_WORKSTATUS_OKAY,
    CDTRACE_WORKSTATUS_DONE  = DTRACE_WORKSTATUS_DONE
} cdtrace_workstatus_t;

/* Status values */
typedef enum {
    CDTRACE_STATUS_NONE    = DTRACE_STATUS_NONE,
    CDTRACE_STATUS_OKAY    = DTRACE_STATUS_OKAY,
    CDTRACE_STATUS_EXITED  = DTRACE_STATUS_EXITED,
    CDTRACE_STATUS_FILLED  = DTRACE_STATUS_FILLED,
    CDTRACE_STATUS_STOPPED = DTRACE_STATUS_STOPPED
} cdtrace_status_t;

/* Consume return values */
typedef enum {
    CDTRACE_CONSUME_ERROR = DTRACE_CONSUME_ERROR,
    CDTRACE_CONSUME_THIS  = DTRACE_CONSUME_THIS,
    CDTRACE_CONSUME_NEXT  = DTRACE_CONSUME_NEXT,
    CDTRACE_CONSUME_ABORT = DTRACE_CONSUME_ABORT
} cdtrace_consume_t;

/* Aggregate walk return values */
typedef enum {
    CDTRACE_AGGWALK_ERROR     = DTRACE_AGGWALK_ERROR,
    CDTRACE_AGGWALK_NEXT      = DTRACE_AGGWALK_NEXT,
    CDTRACE_AGGWALK_ABORT     = DTRACE_AGGWALK_ABORT,
    CDTRACE_AGGWALK_CLEAR     = DTRACE_AGGWALK_CLEAR,
    CDTRACE_AGGWALK_NORMALIZE = DTRACE_AGGWALK_NORMALIZE,
    CDTRACE_AGGWALK_DENORMALIZE = DTRACE_AGGWALK_DENORMALIZE,
    CDTRACE_AGGWALK_REMOVE    = DTRACE_AGGWALK_REMOVE
} cdtrace_aggwalk_t;

/* Handler return values */
typedef enum {
    CDTRACE_HANDLE_ABORT = DTRACE_HANDLE_ABORT,
    CDTRACE_HANDLE_OK    = DTRACE_HANDLE_OK
} cdtrace_handle_t;

/* Drop kinds */
typedef enum {
    CDTRACE_DROP_PRINCIPAL      = DTRACEDROP_PRINCIPAL,
    CDTRACE_DROP_AGGREGATION    = DTRACEDROP_AGGREGATION,
    CDTRACE_DROP_DYNAMIC        = DTRACEDROP_DYNAMIC,
    CDTRACE_DROP_DYNRINSE       = DTRACEDROP_DYNRINSE,
    CDTRACE_DROP_DYNDIRTY       = DTRACEDROP_DYNDIRTY,
    CDTRACE_DROP_SPEC           = DTRACEDROP_SPEC,
    CDTRACE_DROP_SPECBUSY       = DTRACEDROP_SPECBUSY,
    CDTRACE_DROP_SPECUNAVAIL    = DTRACEDROP_SPECUNAVAIL,
    CDTRACE_DROP_STKSTROVERFLOW = DTRACEDROP_STKSTROVERFLOW,
    CDTRACE_DROP_DBLERROR       = DTRACEDROP_DBLERROR
} cdtrace_dropkind_t;

/* Output format */
typedef enum {
    CDTRACE_OFORMAT_TEXT       = DTRACE_OFORMAT_TEXT,
    CDTRACE_OFORMAT_STRUCTURED = DTRACE_OFORMAT_STRUCTURED
} cdtrace_oformat_t;

/*
 * Core lifecycle functions
 */

static inline dtrace_hdl_t *cdtrace_open(int version, int flags, int *errp) {
    return dtrace_open(version, flags, errp);
}

static inline void cdtrace_close(dtrace_hdl_t *dtp) {
    dtrace_close(dtp);
}

static inline int cdtrace_go(dtrace_hdl_t *dtp) {
    return dtrace_go(dtp);
}

static inline int cdtrace_stop(dtrace_hdl_t *dtp) {
    return dtrace_stop(dtp);
}

static inline void cdtrace_sleep(dtrace_hdl_t *dtp) {
    dtrace_sleep(dtp);
}

static inline void cdtrace_update(dtrace_hdl_t *dtp) {
    dtrace_update(dtp);
}

/*
 * Error handling
 */

static inline int cdtrace_errno(dtrace_hdl_t *dtp) {
    return dtrace_errno(dtp);
}

static inline const char *cdtrace_errmsg(dtrace_hdl_t *dtp, int err) {
    return dtrace_errmsg(dtp, err);
}

/*
 * Options
 */

static inline int cdtrace_setopt(dtrace_hdl_t *dtp, const char *opt, const char *val) {
    return dtrace_setopt(dtp, opt, val);
}

static inline int cdtrace_getopt(dtrace_hdl_t *dtp, const char *opt, dtrace_optval_t *valp) {
    return dtrace_getopt(dtp, opt, valp);
}

/*
 * Program compilation and execution
 */

static inline dtrace_prog_t *cdtrace_program_strcompile(
    dtrace_hdl_t *dtp,
    const char *s,
    dtrace_probespec_t spec,
    uint_t cflags,
    int argc,
    char *const argv[])
{
    return dtrace_program_strcompile(dtp, s, spec, cflags, argc, argv);
}

static inline int cdtrace_program_exec(
    dtrace_hdl_t *dtp,
    dtrace_prog_t *pgp,
    dtrace_proginfo_t *pip)
{
    return dtrace_program_exec(dtp, pgp, pip);
}

static inline void cdtrace_program_info(
    dtrace_hdl_t *dtp,
    dtrace_prog_t *pgp,
    dtrace_proginfo_t *pip)
{
    dtrace_program_info(dtp, pgp, pip);
}

/*
 * Data consumption
 */

static inline dtrace_workstatus_t cdtrace_work(
    dtrace_hdl_t *dtp,
    FILE *fp,
    dtrace_consume_probe_f *pfunc,
    dtrace_consume_rec_f *rfunc,
    void *arg)
{
    return dtrace_work(dtp, fp, pfunc, rfunc, arg);
}

static inline int cdtrace_consume(
    dtrace_hdl_t *dtp,
    FILE *fp,
    dtrace_consume_probe_f *pfunc,
    dtrace_consume_rec_f *rfunc,
    void *arg)
{
    return dtrace_consume(dtp, fp, pfunc, rfunc, arg);
}

static inline int cdtrace_status(dtrace_hdl_t *dtp) {
    return dtrace_status(dtp);
}

/*
 * Aggregation
 */

static inline int cdtrace_aggregate_snap(dtrace_hdl_t *dtp) {
    return dtrace_aggregate_snap(dtp);
}

static inline int cdtrace_aggregate_print(dtrace_hdl_t *dtp, FILE *fp,
    dtrace_aggregate_walk_f *func)
{
    return dtrace_aggregate_print(dtp, fp, func);
}

static inline void cdtrace_aggregate_clear(dtrace_hdl_t *dtp) {
    dtrace_aggregate_clear(dtp);
}

static inline int cdtrace_aggregate_walk(dtrace_hdl_t *dtp,
    dtrace_aggregate_f *func, void *arg)
{
    return dtrace_aggregate_walk(dtp, func, arg);
}

static inline int cdtrace_aggregate_walk_sorted(dtrace_hdl_t *dtp,
    dtrace_aggregate_f *func, void *arg)
{
    return dtrace_aggregate_walk_sorted(dtp, func, arg);
}

static inline int cdtrace_aggregate_walk_keysorted(dtrace_hdl_t *dtp,
    dtrace_aggregate_f *func, void *arg)
{
    return dtrace_aggregate_walk_keysorted(dtp, func, arg);
}

static inline int cdtrace_aggregate_walk_valsorted(dtrace_hdl_t *dtp,
    dtrace_aggregate_f *func, void *arg)
{
    return dtrace_aggregate_walk_valsorted(dtp, func, arg);
}

/*
 * Probe iteration
 */

static inline int cdtrace_probe_iter(
    dtrace_hdl_t *dtp,
    const dtrace_probedesc_t *pdp,
    dtrace_probe_f *func,
    void *arg)
{
    return dtrace_probe_iter(dtp, pdp, func, arg);
}

/*
 * Handlers
 */

static inline int cdtrace_handle_err(dtrace_hdl_t *dtp,
    dtrace_handle_err_f *func, void *arg)
{
    return dtrace_handle_err(dtp, func, arg);
}

static inline int cdtrace_handle_drop(dtrace_hdl_t *dtp,
    dtrace_handle_drop_f *func, void *arg)
{
    return dtrace_handle_drop(dtp, func, arg);
}

static inline int cdtrace_handle_buffered(dtrace_hdl_t *dtp,
    dtrace_handle_buffered_f *func, void *arg)
{
    return dtrace_handle_buffered(dtp, func, arg);
}

static inline int cdtrace_handle_proc(dtrace_hdl_t *dtp,
    dtrace_handle_proc_f *func, void *arg)
{
    return dtrace_handle_proc(dtp, func, arg);
}

static inline int cdtrace_handle_setopt(dtrace_hdl_t *dtp,
    dtrace_handle_setopt_f *func, void *arg)
{
    return dtrace_handle_setopt(dtp, func, arg);
}

/*
 * Process control
 */

static inline struct ps_prochandle *cdtrace_proc_create(
    dtrace_hdl_t *dtp,
    const char *file,
    char *const argv[],
    proc_child_func *pcf,
    void *child_arg)
{
    return dtrace_proc_create(dtp, file, argv, pcf, child_arg);
}

static inline struct ps_prochandle *cdtrace_proc_grab(
    dtrace_hdl_t *dtp,
    pid_t pid,
    int flags)
{
    return dtrace_proc_grab(dtp, pid, flags);
}

static inline void cdtrace_proc_release(dtrace_hdl_t *dtp, struct ps_prochandle *P) {
    dtrace_proc_release(dtp, P);
}

static inline void cdtrace_proc_continue(dtrace_hdl_t *dtp, struct ps_prochandle *P) {
    dtrace_proc_continue(dtp, P);
}

/*
 * Output format (JSON/XML)
 */

static inline int cdtrace_oformat_configure(dtrace_hdl_t *dtp) {
    return dtrace_oformat_configure(dtp);
}

static inline int cdtrace_oformat(dtrace_hdl_t *dtp) {
    return dtrace_oformat(dtp);
}

static inline void cdtrace_oformat_setup(dtrace_hdl_t *dtp) {
    dtrace_oformat_setup(dtp);
}

static inline void cdtrace_oformat_teardown(dtrace_hdl_t *dtp) {
    dtrace_oformat_teardown(dtp);
}

/*
 * Utility functions
 */

static inline int cdtrace_version(void) {
    return DTRACE_VERSION;
}

/* Probe description helpers */
static inline const char *cdtrace_probedesc_provider(const dtrace_probedesc_t *pdp) {
    return pdp->dtpd_provider;
}

static inline const char *cdtrace_probedesc_mod(const dtrace_probedesc_t *pdp) {
    return pdp->dtpd_mod;
}

static inline const char *cdtrace_probedesc_func(const dtrace_probedesc_t *pdp) {
    return pdp->dtpd_func;
}

static inline const char *cdtrace_probedesc_name(const dtrace_probedesc_t *pdp) {
    return pdp->dtpd_name;
}

static inline dtrace_id_t cdtrace_probedesc_id(const dtrace_probedesc_t *pdp) {
    return pdp->dtpd_id;
}

/* Aggregation data helpers */
static inline caddr_t cdtrace_aggdata_data(const dtrace_aggdata_t *data) {
    return data->dtada_data;
}

static inline size_t cdtrace_aggdata_size(const dtrace_aggdata_t *data) {
    return data->dtada_size;
}

static inline dtrace_aggdesc_t *cdtrace_aggdata_desc(const dtrace_aggdata_t *data) {
    return data->dtada_desc;
}

/* Error data helpers */
static inline const char *cdtrace_errdata_msg(const dtrace_errdata_t *data) {
    return data->dteda_msg;
}

static inline int cdtrace_errdata_fault(const dtrace_errdata_t *data) {
    return data->dteda_fault;
}

/* Drop data helpers */
static inline dtrace_dropkind_t cdtrace_dropdata_kind(const dtrace_dropdata_t *data) {
    return data->dtdda_kind;
}

static inline uint64_t cdtrace_dropdata_drops(const dtrace_dropdata_t *data) {
    return data->dtdda_drops;
}

static inline const char *cdtrace_dropdata_msg(const dtrace_dropdata_t *data) {
    return data->dtdda_msg;
}

/* Probe data helpers */
static inline processorid_t cdtrace_probedata_cpu(const dtrace_probedata_t *data) {
    return data->dtpda_cpu;
}

static inline caddr_t cdtrace_probedata_data(const dtrace_probedata_t *data) {
    return data->dtpda_data;
}

static inline dtrace_probedesc_t *cdtrace_probedata_pdesc(const dtrace_probedata_t *data) {
    return data->dtpda_pdesc;
}

#endif /* CDTRACE_H */
