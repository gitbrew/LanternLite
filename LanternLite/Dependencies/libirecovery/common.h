/**
  * GreenPois0n Syringe - common.h
  * Copyright (C) 2010 Chronic-Dev Team
  * Copyright (C) 2010 Joshua Hill
  *
  * This program is free software: you can redistribute it and/or modify
  * it under the terms of the GNU General Public License as published by
  * the Free Software Foundation, either version 3 of the License, or
  * (at your option) any later version.
  *
  * This program is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#ifndef COMMON_H
#define COMMON_H

#ifdef __cplusplus
#define EXT_C extern "C"
#else
#define EXT_C extern
#endif

#define LIBSYRINGE_EXPORT EXT_C __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif 
	
#include "libirecovery.h"

#define info(...) printf(__VA_ARGS__)
#define error(...) fprintf(stderr, __VA_ARGS__)
#define debug(...) if(libpois0n_debug) fprintf(stderr, __VA_ARGS__)

LIBSYRINGE_EXPORT int libpois0n_debug;
LIBSYRINGE_EXPORT irecv_client_t irec_client;
LIBSYRINGE_EXPORT irecv_device_t irec_device;

#ifdef __cplusplus
}
#endif

#endif
