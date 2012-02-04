/**
  * GreenPois0n Syringe - libirecovery.h
  * Copyright (C) 2010 Chronic-Dev Team
  * Copyright (C) 2010 Joshua Hill
  * Portions Copyright (C) 2010 Ricky Taylor
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

#ifndef LIBIRECOVERY_H
#define LIBIRECOVERY_H

#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "libusb.h"

#ifdef __cplusplus
#	define EXT_C extern "C"
#else
#	define EXT_C extern
#endif

#ifdef LIBSYRINGE_DYNAMIC
#	define LIBIRECOVERY_DYNAMIC 1
#endif

#define LIBIRECOVERY_EXPORT EXT_C __attribute__((visibility("default")))

#define APPLE_VENDOR_ID 0x05AC

#define CPID_UNKNOWN        -1
#define CPID_IPHONE2G     8900
#define CPID_IPOD1G       8900
#define CPID_IPHONE3G     8900
#define CPID_IPOD2G       8720
#define CPID_IPHONE3GS    8920
#define CPID_IPOD3G       8922
#define CPID_IPAD1G       8930
#define CPID_IPHONE4      8930
#define CPID_IPOD4G       8930
#define CPID_APPLETV2     8930
#define CPID_IPHONE42     8930

#define BDID_UNKNOWN        -1
#define BDID_IPHONE2G        0
#define BDID_IPOD1G          2
#define BDID_IPHONE3G        4
#define BDID_IPOD2G          0
#define BDID_IPHONE3GS       0
#define BDID_IPOD3G          2
#define BDID_IPAD1G          2
#define BDID_IPHONE4         0
#define BDID_IPOD4G          8
#define BDID_APPLETV2       10
#define BDID_IPHONE42        6

#define DEVICE_UNKNOWN      -1
#define DEVICE_IPHONE2G      0
#define DEVICE_IPOD1G        1
#define DEVICE_IPHONE3G      2
#define DEVICE_IPOD2G        3
#define DEVICE_IPHONE3GS     4
#define DEVICE_IPOD3G        5
#define DEVICE_IPAD1G        6
#define DEVICE_IPHONE4       7
#define DEVICE_IPOD4G        8
#define DEVICE_APPLETV2      9
#define DEVICE_IPHONE42      10

enum
{
	kRecoveryMode1 = 0x1280,
	kRecoveryMode2 = 0x1281,
	kRecoveryMode3 = 0x1282,
	kRecoveryMode4 = 0x1283,
	kDfuMode = 0x1227
};

typedef enum
{
	IRECV_E_SUCCESS = 0,
	IRECV_E_NO_DEVICE = -1,
	IRECV_E_OUT_OF_MEMORY = -2,
	IRECV_E_UNABLE_TO_CONNECT = -3,
	IRECV_E_INVALID_INPUT = -4,
	IRECV_E_FILE_NOT_FOUND = -5,
	IRECV_E_USB_UPLOAD = -6,
	IRECV_E_USB_STATUS = -7,
	IRECV_E_USB_INTERFACE = -8,
	IRECV_E_USB_CONFIGURATION = -9,
	IRECV_E_PIPE = -10,
	IRECV_E_TIMEOUT = -11,
	IRECV_E_UNKNOWN_ERROR = -255
} irecv_error_t;

typedef enum
{
	IRECV_RECEIVED = 1,
	IRECV_PRECOMMAND = 2,
	IRECV_POSTCOMMAND = 3,
	IRECV_CONNECTED = 4,
	IRECV_DISCONNECTED = 5,
	IRECV_PROGRESS = 6
} irecv_event_type;

typedef struct
{
	int size;
	const char* data;
	double progress;
	irecv_event_type type;
} irecv_event_t;

struct irecv_client;
typedef struct irecv_client* irecv_client_t;
typedef const struct irecv_device* irecv_device_t;
typedef int(*irecv_event_cb_t)(irecv_client_t client, const irecv_event_t* event);

struct irecv_client
{
	int debug;
	int config;
	int interface;
	int alt_interface;
	unsigned short mode;
	char serial[256];
	
	libusb_device_handle* handle;
	
	irecv_event_cb_t progress_callback;
	irecv_event_cb_t received_callback;
	irecv_event_cb_t connected_callback;
	irecv_event_cb_t precommand_callback;
	irecv_event_cb_t postcommand_callback;
	irecv_event_cb_t disconnected_callback;
};

struct irecv_device
{
	int index;
	const char* product;
	const char* model;
	unsigned int board_id;
	unsigned int chip_id;
	const char* url;
};

static const struct irecv_device irecv_devices[] =
{
	{  0, "iPhone1,1",  "m68ap",  0,  8900,
	"http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPhone/061-7481.20100202.4orot/iPhone1,1_3.1.3_7E18_Restore.ipsw" },
	
  {  1, "iPod1,1",    "n45ap",  2,  8900,
	NULL },
	
  {  2, "iPhone1,2",  "n82ap",  4,  8900,
	"http://appldnld.apple.com/iPhone4/061-7932.20100908.3fgt5/iPhone1,2_4.1_8B117_Restore.ipsw" },
	
	{  3, "iPod2,1",    "n72ap",  0,  8720,
	"http://appldnld.apple.com/iPhone4/061-9855.20101122.Lrft6/iPod2,1_4.2.1_8C148_Restore.ipsw" },
	
  {  4, "iPhone2,1",  "n88ap",  0,  8920,
	"http://appldnld.apple.com/iPhone4/041-1965.20110721.gxUB5/iPhone2,1_4.3.5_8L1_Restore.ipsw" },
	
  {  5, "iPod3,1",    "n18ap",  2,  8922,
	"http://appldnld.apple.com/iPhone4/041-1964.20110721.P9Cg3/iPod3,1_4.3.5_8L1_Restore.ipsw" },
	
  {  6, "iPad1,1",    "k48ap",  2,  8930,
	"http://appldnld.apple.com/iPhone4/041-1957.20110721.6UHaN/iPad1,1_4.3.5_8L1_Restore.ipsw" },
	
  {  7, "iPhone3,1",  "n90ap",  0,  8930,
	"http://appldnld.apple.com/iPhone4/041-1966.20110721.V3Ufe/iPhone3,1_4.3.5_8L1_Restore.ipsw" },
	
  {  8, "iPod4,1",    "n81ap",  8,  8930,
	"http://appldnld.apple.com/iPhone4/041-1963.20110721.Huant/iPod4,1_4.3.5_8L1_Restore.ipsw" },
	
  {  9, "AppleTV2,1", "k66ap",  10,  8930,
	"http://appldnld.apple.com/AppleTV/041-0574.20110322.Dcfr5/AppleTV2,1_4.3_8F202_Restore.ipswy" },
	
  { 10, "iPhone3,3",  "n92ap",  BDID_IPHONE42,  CPID_IPHONE42,
  "http://appldnld.apple.com/iPhone4/041-1916.20110715.V5rUA/iPhone3,3_4.2.9_8E501_Restore.ipsw" },
  
  { -1, NULL, NULL,  -1,  -1,
	NULL }
};

LIBIRECOVERY_EXPORT void irecv_set_debug_level(int level);
LIBIRECOVERY_EXPORT const char* irecv_strerror(irecv_error_t error);
LIBIRECOVERY_EXPORT irecv_error_t irecv_open_attempts(irecv_client_t* pclient, int attempts);
LIBIRECOVERY_EXPORT irecv_error_t irecv_open(irecv_client_t* client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_reset(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_close(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_receive(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_send_exploit(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_execute_script(irecv_client_t client, const char* filename);
LIBIRECOVERY_EXPORT irecv_error_t irecv_set_configuration(irecv_client_t client, int configuration);

LIBIRECOVERY_EXPORT irecv_error_t irecv_event_subscribe(irecv_client_t client, irecv_event_type type, irecv_event_cb_t callback, void *user_data);
LIBIRECOVERY_EXPORT irecv_error_t irecv_event_unsubscribe(irecv_client_t client, irecv_event_type type);

LIBIRECOVERY_EXPORT irecv_error_t irecv_send_file(irecv_client_t client, const char* filename, int dfuNotifyFinished);
LIBIRECOVERY_EXPORT irecv_error_t irecv_send_command(irecv_client_t client, const char* command);
LIBIRECOVERY_EXPORT irecv_error_t irecv_send_buffer(irecv_client_t client, unsigned char* buffer, unsigned long length, int dfuNotifyFinished);

LIBIRECOVERY_EXPORT irecv_error_t irecv_saveenv(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_getret(irecv_client_t client, unsigned int* value);
LIBIRECOVERY_EXPORT irecv_error_t irecv_getenv(irecv_client_t client, const char* variable, char** value);
LIBIRECOVERY_EXPORT irecv_error_t irecv_setenv(irecv_client_t client, const char* variable, const char* value);
LIBIRECOVERY_EXPORT irecv_error_t irecv_set_interface(irecv_client_t client, int interface, int alt_interface);
LIBIRECOVERY_EXPORT irecv_error_t irecv_get_cpid(irecv_client_t client, unsigned int* cpid);
LIBIRECOVERY_EXPORT irecv_error_t irecv_get_bdid(irecv_client_t client, unsigned int* bdid);
LIBIRECOVERY_EXPORT irecv_error_t irecv_get_ecid(irecv_client_t client, unsigned long long* ecid);
LIBIRECOVERY_EXPORT void irecv_hexdump(unsigned char* buf, unsigned int len, unsigned int addr);

LIBIRECOVERY_EXPORT void irecv_init();
LIBIRECOVERY_EXPORT void irecv_exit();
LIBIRECOVERY_EXPORT irecv_client_t irecv_reconnect(irecv_client_t client, int initial_pause);
LIBIRECOVERY_EXPORT irecv_error_t irecv_reset_counters(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_finish_transfer(irecv_client_t client);
LIBIRECOVERY_EXPORT irecv_error_t irecv_recv_buffer(irecv_client_t client, char* buffer, unsigned long length);
LIBIRECOVERY_EXPORT irecv_error_t irecv_get_device(irecv_client_t client, irecv_device_t* device);

LIBIRECOVERY_EXPORT int irecv_control_transfer(irecv_client_t client,
                                               uint8_t bmRequestType,
                                               uint8_t bRequest,
                                               uint16_t wValue,
                                               uint16_t wIndex,
                                               unsigned char *data,
                                               uint16_t wLength,
                                               unsigned int timeout);

#ifdef __cplusplus
}
#endif

#endif
