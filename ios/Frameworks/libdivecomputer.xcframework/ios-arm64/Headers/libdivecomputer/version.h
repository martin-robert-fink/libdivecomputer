/*
 * libdivecomputer
 *
 * Copyright (C) 2010 Jef Driesen
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301 USA
 */

#ifndef DC_VERSION_H
#define DC_VERSION_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#define DC_VERSION "0.10.0-devel"
#define DC_VERSION_MAJOR 0
#define DC_VERSION_MINOR 10
#define DC_VERSION_MICRO 0

#define DC_VERSION_CHECK(major,minor,micro) \
	(DC_VERSION_MAJOR > (major) || \
	(DC_VERSION_MAJOR == (major) && DC_VERSION_MINOR > (minor)) || \
	(DC_VERSION_MAJOR == (major) && DC_VERSION_MINOR == (minor) && \
		DC_VERSION_MICRO >= (micro)))

typedef struct dc_version_t {
	unsigned int major;
	unsigned int minor;
	unsigned int micro;
} dc_version_t;

const char *
dc_version (dc_version_t *version);

int
dc_version_check (unsigned int major, unsigned int minor, unsigned int micro);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* DC_VERSION_H */
