/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CACL_H
#define CACL_H

#include <sys/types.h>
#include <sys/acl.h>
#include <errno.h>

/*
 * Re-export ACL constants for Swift access.
 * Swift cannot import macros directly, so we expose them as static constants.
 */

/* ACL brands */
static const int CACL_BRAND_UNKNOWN = ACL_BRAND_UNKNOWN;
static const int CACL_BRAND_POSIX = ACL_BRAND_POSIX;
static const int CACL_BRAND_NFS4 = ACL_BRAND_NFS4;

/* ACL tag types */
static const acl_tag_t CACL_UNDEFINED_TAG = ACL_UNDEFINED_TAG;
static const acl_tag_t CACL_USER_OBJ = ACL_USER_OBJ;
static const acl_tag_t CACL_USER = ACL_USER;
static const acl_tag_t CACL_GROUP_OBJ = ACL_GROUP_OBJ;
static const acl_tag_t CACL_GROUP = ACL_GROUP;
static const acl_tag_t CACL_MASK = ACL_MASK;
static const acl_tag_t CACL_OTHER = ACL_OTHER;
static const acl_tag_t CACL_EVERYONE = ACL_EVERYONE;

/* NFSv4 entry types */
static const acl_entry_type_t CACL_ENTRY_TYPE_ALLOW = ACL_ENTRY_TYPE_ALLOW;
static const acl_entry_type_t CACL_ENTRY_TYPE_DENY = ACL_ENTRY_TYPE_DENY;
static const acl_entry_type_t CACL_ENTRY_TYPE_AUDIT = ACL_ENTRY_TYPE_AUDIT;
static const acl_entry_type_t CACL_ENTRY_TYPE_ALARM = ACL_ENTRY_TYPE_ALARM;

/* ACL types */
static const acl_type_t CACL_TYPE_ACCESS = ACL_TYPE_ACCESS;
static const acl_type_t CACL_TYPE_DEFAULT = ACL_TYPE_DEFAULT;
static const acl_type_t CACL_TYPE_NFS4 = ACL_TYPE_NFS4;

/* POSIX.1e permissions */
static const acl_perm_t CACL_EXECUTE = ACL_EXECUTE;
static const acl_perm_t CACL_WRITE = ACL_WRITE;
static const acl_perm_t CACL_READ = ACL_READ;
static const acl_perm_t CACL_PERM_NONE = ACL_PERM_NONE;

/* NFSv4 permissions */
static const acl_perm_t CACL_READ_DATA = ACL_READ_DATA;
static const acl_perm_t CACL_LIST_DIRECTORY = ACL_READ_DATA;  /* Alias for directories */
static const acl_perm_t CACL_WRITE_DATA = ACL_WRITE_DATA;
static const acl_perm_t CACL_ADD_FILE = ACL_WRITE_DATA;  /* Alias for directories */
static const acl_perm_t CACL_APPEND_DATA = ACL_APPEND_DATA;
static const acl_perm_t CACL_ADD_SUBDIRECTORY = ACL_APPEND_DATA;  /* Alias for directories */
static const acl_perm_t CACL_READ_NAMED_ATTRS = ACL_READ_NAMED_ATTRS;
static const acl_perm_t CACL_WRITE_NAMED_ATTRS = ACL_WRITE_NAMED_ATTRS;
static const acl_perm_t CACL_DELETE_CHILD = ACL_DELETE_CHILD;
static const acl_perm_t CACL_READ_ATTRIBUTES = ACL_READ_ATTRIBUTES;
static const acl_perm_t CACL_WRITE_ATTRIBUTES = ACL_WRITE_ATTRIBUTES;
static const acl_perm_t CACL_DELETE = ACL_DELETE;
static const acl_perm_t CACL_READ_ACL = ACL_READ_ACL;
static const acl_perm_t CACL_WRITE_ACL = ACL_WRITE_ACL;
static const acl_perm_t CACL_WRITE_OWNER = ACL_WRITE_OWNER;
static const acl_perm_t CACL_SYNCHRONIZE = ACL_SYNCHRONIZE;

/* NFSv4 permission sets */
static const acl_perm_t CACL_FULL_SET = ACL_FULL_SET;
static const acl_perm_t CACL_MODIFY_SET = ACL_MODIFY_SET;
static const acl_perm_t CACL_READ_SET = ACL_READ_SET;
static const acl_perm_t CACL_WRITE_SET = ACL_WRITE_SET;

/* NFSv4 inheritance flags */
static const acl_flag_t CACL_ENTRY_FILE_INHERIT = ACL_ENTRY_FILE_INHERIT;
static const acl_flag_t CACL_ENTRY_DIRECTORY_INHERIT = ACL_ENTRY_DIRECTORY_INHERIT;
static const acl_flag_t CACL_ENTRY_NO_PROPAGATE_INHERIT = ACL_ENTRY_NO_PROPAGATE_INHERIT;
static const acl_flag_t CACL_ENTRY_INHERIT_ONLY = ACL_ENTRY_INHERIT_ONLY;
static const acl_flag_t CACL_ENTRY_SUCCESSFUL_ACCESS = ACL_ENTRY_SUCCESSFUL_ACCESS;
static const acl_flag_t CACL_ENTRY_FAILED_ACCESS = ACL_ENTRY_FAILED_ACCESS;
static const acl_flag_t CACL_ENTRY_INHERITED = ACL_ENTRY_INHERITED;

/* Entry IDs for acl_get_entry */
static const int CACL_FIRST_ENTRY = ACL_FIRST_ENTRY;
static const int CACL_NEXT_ENTRY = ACL_NEXT_ENTRY;

/* Text output flags for acl_to_text_np */
static const int CACL_TEXT_VERBOSE = ACL_TEXT_VERBOSE;
static const int CACL_TEXT_NUMERIC_IDS = ACL_TEXT_NUMERIC_IDS;
static const int CACL_TEXT_APPEND_ID = ACL_TEXT_APPEND_ID;

/* Maximum entries */
static const int CACL_MAX_ENTRIES = ACL_MAX_ENTRIES;

/* Undefined ID for entries without qualifier */
static const uid_t CACL_UNDEFINED_ID = ACL_UNDEFINED_ID;

#endif /* CACL_H */
