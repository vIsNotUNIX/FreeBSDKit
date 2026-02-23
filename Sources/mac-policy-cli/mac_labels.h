/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/*
 * Reference C API for reading MACF labels
 *
 * This header shows the recommended API for a C library to read labels
 * created by the maclabel tool. The actual implementation should be
 * created separately.
 *
 * Usage:
 *   // Attribute name must match your maclabel configuration
 *   const char *attr_name = "mac.labels";  // or "mac.network", etc.
 *   struct mac_label *labels = mac_label_read("/bin/sh", attr_name);
 *   if (labels) {
 *       const char *trust = mac_label_get(labels, "trust");
 *       if (trust && strcmp(trust, "system") == 0) {
 *           // High trust binary
 *       }
 *       mac_label_free(labels);
 *   }
 */

#ifndef _MAC_LABELS_H_
#define _MAC_LABELS_H_

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Opaque structure representing parsed MAC labels
 */
struct mac_label;

/*
 * Read MAC labels from a file's extended attributes
 *
 * Reads the system namespace extended attribute (e.g., system.mac.labels,
 * system.mac.network, etc.) and parses it into an opaque mac_label structure.
 *
 * The attribute name should match the one specified in your maclabel
 * configuration file.
 *
 * Parameters:
 *   - path: Path to the file to read labels from
 *   - attr_name: Name of the extended attribute (e.g., "mac.labels")
 *
 * Returns:
 *   - Pointer to mac_label on success (must be freed with mac_label_free)
 *   - NULL on error (errno set appropriately):
 *       ENOENT - File not found
 *       ENOATTR - No labels on file
 *       ENOMEM - Out of memory
 *       EINVAL - Invalid label format
 */
struct mac_label *mac_label_read(const char *path, const char *attr_name);

/*
 * Read MAC labels from a file descriptor
 *
 * Same as mac_label_read() but operates on an open file descriptor.
 *
 * Parameters:
 *   - fd: Open file descriptor
 *   - attr_name: Name of the extended attribute (e.g., "mac.labels")
 */
struct mac_label *mac_label_read_fd(int fd, const char *attr_name);

/*
 * Get the value of a specific label attribute
 *
 * Returns:
 *   - Pointer to value string (valid until mac_label_free is called)
 *   - NULL if attribute not found
 *
 * The returned string is owned by the mac_label structure and must not
 * be freed or modified by the caller.
 */
const char *mac_label_get(const struct mac_label *labels, const char *key);

/*
 * Check if a specific attribute exists
 *
 * Returns:
 *   - 1 if attribute exists
 *   - 0 if attribute does not exist
 */
int mac_label_has(const struct mac_label *labels, const char *key);

/*
 * Get number of attributes in the label
 */
size_t mac_label_count(const struct mac_label *labels);

/*
 * Iterate over all attributes
 *
 * Calls callback for each key-value pair. Callback receives:
 *   - key: attribute name
 *   - value: attribute value
 *   - ctx: user-provided context pointer
 *
 * Iteration stops if callback returns non-zero.
 *
 * Returns:
 *   - 0 on success (all attributes visited)
 *   - Non-zero if callback returned non-zero
 */
int mac_label_foreach(
    const struct mac_label *labels,
    int (*callback)(const char *key, const char *value, void *ctx),
    void *ctx
);

/*
 * Free a mac_label structure
 *
 * Frees all memory associated with the label structure. After calling
 * this function, the label pointer and any strings returned by
 * mac_label_get() are invalid.
 */
void mac_label_free(struct mac_label *labels);

/*
 * Parse MAC labels from a string
 *
 * Parses labels from the wire format (newline-separated key=value pairs)
 * instead of reading from extended attributes.
 *
 * Useful for testing or when labels are obtained through other means.
 *
 * Returns:
 *   - Pointer to mac_label on success
 *   - NULL on error (errno = EINVAL for invalid format, ENOMEM for OOM)
 */
struct mac_label *mac_label_parse(const char *data, size_t len);

/*
 * Serialize labels to wire format
 *
 * Converts a mac_label structure back to the wire format.
 *
 * Parameters:
 *   - labels: Label structure to serialize
 *   - buf: Output buffer (can be NULL to query size)
 *   - bufsize: Size of output buffer
 *
 * Returns:
 *   - Number of bytes written (excluding null terminator)
 *   - If buf is NULL or bufsize is too small, returns required size
 *   - Negative on error
 */
ssize_t mac_label_serialize(
    const struct mac_label *labels,
    char *buf,
    size_t bufsize
);

#ifdef __cplusplus
}
#endif

#endif /* !_MAC_LABELS_H_ */
