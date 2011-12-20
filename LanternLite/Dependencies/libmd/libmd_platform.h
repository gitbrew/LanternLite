#pragma once
#ifndef _PLATFORM_H
#define _PLATFORM_H

#include <objc/objc.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <netinet/ip.h>
#include <mach/error.h>

enum LIBMD_ERROR {
	LIBMD_ERR_SUCCESS				= 0x00,
	LIBMD_ERR_DISCONNECTED			= 0x01,
	LIBMD_ERR_CONNECT_ERROR			= 0x02,
	LIBMD_ERR_SERVICE_ERROR			= 0x03,
	LIBMD_ERR_BIND_ERROR			= 0x04,
	LIBMD_ERR_GENERAL_ERROR			= 0x05,
	LIBMD_ERR_OS_TOO_FUCKING_OLD	= 0x06,
	LIBMD_ERR_REGISTRY_ERROR		= 0x07,
	LIBMD_ERR_LOAD_ERROR			= 0x08,
	LIBMD_ERR_BAD_OPTIONS			= 0x09,
	LIBMD_ERR_BAD_OPTION_COMBO		= 0x0A,
};

typedef enum LIBMD_ERROR LIBMD_ERROR;

#define _cdecl

#define THREADPROCATTR 

#define Sleep(ms) usleep(ms*1000)

#define SOCKET_ERROR -1

#ifdef __cplusplus
extern "C" {
#endif

	LIBMD_API LIBMD_ERROR libmd_platform_init();

#ifdef __cplusplus
}
#endif

#endif //_PLATFORM_H
