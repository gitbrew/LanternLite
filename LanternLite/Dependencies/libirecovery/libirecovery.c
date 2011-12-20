/**
 * GreenPois0n Syringe - libirecovery.c
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "common.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#include "libusb.h"
#include "darwin_usb.h"

#include "libirecovery.h"

#define BUFFER_SIZE 0x1000

static int libirecovery_debug = 0;
static libusb_context* libirecovery_context = NULL;

int irecv_write_file(const char* filename, const void* data, size_t size);
int irecv_read_file(const char* filename, char** data, uint32_t* size);

#undef debug
#define debug(...) if(libirecovery_debug) fprintf(stderr, __VA_ARGS__)

int check_context(irecv_client_t client)
{
	if (client == NULL || client->handle == NULL)
	{
		return IRECV_E_NO_DEVICE;
	}
	
	return IRECV_E_SUCCESS;
}

void irecv_init()
{
	libusb_init(&libirecovery_context);
}

void irecv_exit()
{
	if (libirecovery_context != NULL) {
		libusb_exit(libirecovery_context);
		libirecovery_context = NULL;
	}
}

static void DummyCallback(void *refcon, IOReturn result, void *arg0)
{
	// not used
}


int irecv_control_transfer(irecv_client_t client,
                           uint8_t bmRequestType,
                           uint8_t bRequest,
                           uint16_t wValue,
                           uint16_t wIndex,
                           unsigned char *data,
                           uint16_t wLength,
                           unsigned int timeout)
{
	if (timeout <= 10)
	{
		
		// pod2g: dirty hack for limera1n support.
		IOReturn kresult;
		IOUSBDevRequest req;
		bzero(&req, sizeof(req));
		//struct darwin_device_handle_priv *priv = (struct darwin_device_handle_priv *)client->handle->os_priv;
		struct darwin_device_priv *dpriv = (struct darwin_device_priv *)client->handle->dev->os_priv;
		req.bmRequestType     = bmRequestType;
		req.bRequest          = bRequest;
		req.wValue            = OSSwapLittleToHostInt16 (wValue);
		req.wIndex            = OSSwapLittleToHostInt16 (wIndex);
		req.wLength           = OSSwapLittleToHostInt16 (wLength);
		req.pData             = data + LIBUSB_CONTROL_SETUP_SIZE;
		kresult = (*(dpriv->device))->DeviceRequestAsync(dpriv->device, &req, (IOAsyncCallback1) DummyCallback, NULL);
		usleep(5 * 1000);
		kresult = (*(dpriv->device))->USBDeviceAbortPipeZero (dpriv->device);
		return kresult == KERN_SUCCESS ? 0 : -1;
		
	}
	else
	{
		return libusb_control_transfer(client->handle, bmRequestType, bRequest, wValue, wIndex, data, wLength, timeout);
	}
}

int irecv_bulk_transfer(irecv_client_t client,
                        unsigned char endpoint,
                        unsigned char *data,
                        int length,
                        int *transferred,
                        unsigned int timeout)
{
	return libusb_bulk_transfer(client->handle, endpoint, data, length, transferred, timeout);
}

int irecv_get_string_descriptor_ascii(irecv_client_t client, uint8_t desc_index, unsigned char * buffer, int size)
{
	return libusb_get_string_descriptor_ascii(client->handle, desc_index, buffer, size);
}

irecv_error_t irecv_open(irecv_client_t* pclient)
{
	int i = 0;
	struct libusb_device* usb_device = NULL;
	struct libusb_device** usb_device_list = NULL;
	struct libusb_device_handle* usb_handle = NULL;
	struct libusb_device_descriptor usb_descriptor;
	
	*pclient = NULL;
	if(libirecovery_debug)
	{
		irecv_set_debug_level(libirecovery_debug);
	}
	
	irecv_error_t error = IRECV_E_SUCCESS;
	int usb_device_count = libusb_get_device_list(libirecovery_context, &usb_device_list);
	for (i = 0; i < usb_device_count; i++)
	{
		usb_device = usb_device_list[i];
		libusb_get_device_descriptor(usb_device, &usb_descriptor);
		if (usb_descriptor.idVendor == APPLE_VENDOR_ID)
		{
			/* verify this device is in a mode we understand */
			if (usb_descriptor.idProduct == kRecoveryMode1 ||
				usb_descriptor.idProduct == kRecoveryMode2 ||
				usb_descriptor.idProduct == kRecoveryMode3 ||
				usb_descriptor.idProduct == kRecoveryMode4 ||
				usb_descriptor.idProduct == kDfuMode)
			{
				debug("opening device %04x:%04x...\n", usb_descriptor.idVendor, usb_descriptor.idProduct);
				
				libusb_open(usb_device, &usb_handle);
				if (usb_handle == NULL)
				{
					libusb_free_device_list(usb_device_list, 1);
					libusb_close(usb_handle);
					libusb_exit(libirecovery_context);
					return IRECV_E_UNABLE_TO_CONNECT;
				}
				libusb_free_device_list(usb_device_list, 1);
				
				irecv_client_t client = (irecv_client_t) malloc(sizeof(struct irecv_client));
				if (client == NULL)
				{
					libusb_close(usb_handle);
					libusb_exit(libirecovery_context);
					return IRECV_E_OUT_OF_MEMORY;
				}
				
				memset(client, '\0', sizeof(struct irecv_client));
				client->interface = 0;
				client->handle = usb_handle;
				client->mode = usb_descriptor.idProduct;
				if (client->mode != kDfuMode)
				{
					error = irecv_set_configuration(client, 1);
					if (error != IRECV_E_SUCCESS)
					{
						return error;
					}
					error = irecv_set_interface(client, 0, 0);
					if (error != IRECV_E_SUCCESS)
					{
						return error;
					}
				}
				
				/* cache usb serial */
				irecv_get_string_descriptor_ascii(client, usb_descriptor.iSerialNumber, (unsigned char*) client->serial, 255);
				
				*pclient = client;
				return IRECV_E_SUCCESS;
			}
		}
	}
	
	return IRECV_E_UNABLE_TO_CONNECT;
}

irecv_error_t irecv_set_configuration(irecv_client_t client, int configuration)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	debug("Setting to configuration %d\n", configuration);
	
	int current = 0;
	libusb_get_configuration(client->handle, &current);
	if (current != configuration)
	{
		if (libusb_set_configuration(client->handle, configuration) < 0)
		{
			return IRECV_E_USB_CONFIGURATION;
		}
	}
	
	client->config = configuration;
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_set_interface(irecv_client_t client, int interface, int alt_interface)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	libusb_release_interface(client->handle, client->interface);
	
	debug("Setting to interface %d:%d\n", interface, alt_interface);
	if (libusb_claim_interface(client->handle, interface) < 0)
	{
		return IRECV_E_USB_INTERFACE;
	}
	
	if (libusb_set_interface_alt_setting(client->handle, interface, alt_interface) < 0)
	{
		return IRECV_E_USB_INTERFACE;
	}
	
	client->interface = interface;
	client->alt_interface = alt_interface;
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_reset(irecv_client_t client)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	libusb_reset_device(client->handle);
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_open_attempts(irecv_client_t* pclient, int attempts)
{
	int i;
	
	for (i = 0; i < attempts; i++)
	{
		if (irecv_open(pclient) != IRECV_E_SUCCESS)
		{
			debug("Connection failed. Waiting 1 sec before retry.\n");
			sleep(1);
		}
		else
		{
			return IRECV_E_SUCCESS;
		}		
	}
	
	return IRECV_E_UNABLE_TO_CONNECT;       
}

irecv_error_t irecv_event_subscribe(irecv_client_t client, irecv_event_type type, irecv_event_cb_t callback, void* user_data)
{
	switch(type)
	{
		case IRECV_RECEIVED:
			client->received_callback = callback;
			break;
			
		case IRECV_PROGRESS:
			client->progress_callback = callback;
			
		case IRECV_CONNECTED:
			client->connected_callback = callback;
			
		case IRECV_PRECOMMAND:
			client->precommand_callback = callback;
			break;
			
		case IRECV_POSTCOMMAND:
			client->postcommand_callback = callback;
			break;
			
		case IRECV_DISCONNECTED:
			client->disconnected_callback = callback;
			
		default:
			return IRECV_E_UNKNOWN_ERROR;
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_event_unsubscribe(irecv_client_t client, irecv_event_type type)
{
	switch(type)
	{
		case IRECV_RECEIVED:
			client->received_callback = NULL;
			break;
			
		case IRECV_PROGRESS:
			client->progress_callback = NULL;
			
		case IRECV_CONNECTED:
			client->connected_callback = NULL;
			
		case IRECV_PRECOMMAND:
			client->precommand_callback = NULL;
			break;
			
		case IRECV_POSTCOMMAND:
			client->postcommand_callback = NULL;
			break;
			
		case IRECV_DISCONNECTED:
			client->disconnected_callback = NULL;
			
		default:
			return IRECV_E_UNKNOWN_ERROR;
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_close(irecv_client_t client)
{
	if (client != NULL)
	{
		if(client->disconnected_callback != NULL)
		{
			irecv_event_t event;
			event.size = 0;
			event.data = NULL;
			event.progress = 0;
			event.type = IRECV_DISCONNECTED;
			client->disconnected_callback(client, &event);
		}
		
		if (client->handle != NULL)
		{
			if (client->mode != kDfuMode)
			{
				libusb_release_interface(client->handle, client->interface);
			}
			libusb_close(client->handle);
			client->handle = NULL;
		}
		
		free(client);
		client = NULL;
	}
	
	return IRECV_E_SUCCESS;
}

void irecv_set_debug_level(int level)
{
	libirecovery_debug = level;
	
	if(libirecovery_context)
	{
		libusb_set_debug(libirecovery_context, libirecovery_debug);
	}
}

static irecv_error_t irecv_send_command_raw(irecv_client_t client, const char* command)
{
	unsigned int length = strlen(command);
	if (length >= 0x100)
	{
		length = 0xFF;
	}
	
	if (length > 0)
	{
		int rc = irecv_control_transfer(client, 0x40, 0, 0, 0, (unsigned char*) command, length + 1, 1000);
		if(rc <= 0)
		{
			printf("$$$ irecv_send_command_raw failed with %d\n", rc);
		}
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_send_command(irecv_client_t client, const char* command)
{
	irecv_error_t error = IRECV_E_SUCCESS;
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	unsigned int length = strlen(command);
	if (length >= 0x100)
	{
		length = 0xFF;
	}
	
	irecv_event_t event;
	if(client->precommand_callback != NULL)
	{
		event.size = length;
		event.data = command;
		event.type = IRECV_PRECOMMAND;
		if(client->precommand_callback(client, &event))
		{
			return IRECV_E_SUCCESS;
		}
	}
	
	error = irecv_send_command_raw(client, command);
	if (error != IRECV_E_SUCCESS)
	{
		debug("Failed to send command %s\n", command);
		if (error != IRECV_E_PIPE)
			return error;
	}
	
	if(client->postcommand_callback != NULL)
	{
		event.size = length;
		event.data = command;
		event.type = IRECV_POSTCOMMAND;
		if(client->postcommand_callback(client, &event))
		{
			return IRECV_E_SUCCESS;
		}
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_send_file(irecv_client_t client, const char* filename, int dfuNotifyFinished)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	FILE* file = fopen(filename, "rb");
	if (file == NULL)
	{
		return IRECV_E_FILE_NOT_FOUND;
	}
	
	fseek(file, 0, SEEK_END);
	long length = ftell(file);
	fseek(file, 0, SEEK_SET);
	
	char* buffer = (char*) malloc(length);
	if (buffer == NULL)
	{
		fclose(file);
		return IRECV_E_OUT_OF_MEMORY;
	}
	
	long bytes = fread(buffer, 1, length, file);
	fclose(file);
	
	// DEBUGGING
	printf("bytes: %ld\n", bytes);
	printf("length: %ld\n", length);
	//
	
	if (bytes != length)
	{
		free(buffer);
		return IRECV_E_UNKNOWN_ERROR;
	}
	
	irecv_error_t error = irecv_send_buffer(client, (unsigned char*)buffer, length, dfuNotifyFinished);
	free(buffer);
	return error;
}

irecv_error_t irecv_get_status(irecv_client_t client, unsigned int* status)
{
	if (check_context(client) != IRECV_E_SUCCESS)
	{
		*status = 0;
		return IRECV_E_NO_DEVICE;
	}
	
	unsigned char buffer[6];
	memset(buffer, '\0', 6);
	if (irecv_control_transfer(client, 0xA1, 3, 0, 0, buffer, 6, 1000) != 6)
	{
		*status = 0;
		return IRECV_E_USB_STATUS;
	}
	
	*status = (unsigned int) buffer[4];
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_send_buffer(irecv_client_t client, unsigned char* buffer, unsigned long length, int dfuNotifyFinished)
{
	irecv_error_t error = IRECV_E_SUCCESS;
	int recovery_mode = (client->mode != kDfuMode);
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	int packet_size = 0x800;
	int last = length % packet_size;
	int packets = length / packet_size;
	if (last != 0)
	{
		packets++;
	}
	else
	{
		last = packet_size;
	}
	
	/* initiate transfer */
	if (recovery_mode)
	{
		int ret = irecv_control_transfer(client, 0x41, 0, 0, 0, NULL, 0, 1000);
		if (ret < 0)
		{
			printf("$$$ retrying start of send buffer\n");
			int ret = irecv_control_transfer(client, 0x41, 0, 0, 0, NULL, 0, 1000);
			if (ret < 0)
			{
				error = IRECV_E_UNKNOWN_ERROR;
				return error;
			}
		}
	}
	
	int i = 0;
	//double progress = 0;
	unsigned long count = 0;
	unsigned int status = 0;
	int bytes = 0;
	for (i = 0; i < packets; i++)
	{
		int size = (i + 1) < packets ? packet_size : last;
		
		/* Use bulk transfer for recovery mode and control transfer for DFU and WTF mode */
		if (recovery_mode)
		{
			int ret = irecv_bulk_transfer(client, 0x04, &buffer[i * packet_size], size, &bytes, 1000);
			if (ret < 0)
				error = IRECV_E_UNKNOWN_ERROR;
			
			
		}
		else
		{
			bytes = irecv_control_transfer(client, 0x21, 1, 0, 0, &buffer[i * packet_size], size, 1000);
		}
		
		if (bytes != size)
		{
			return IRECV_E_USB_UPLOAD;
		}
		
		if (!recovery_mode)
		{
			error = irecv_get_status(client, &status);
		}
		
		if (error != IRECV_E_SUCCESS)
		{
			return error;
		}
		
		if (!recovery_mode && status != 5)
		{
			return IRECV_E_USB_UPLOAD;
		}
		
		count += size;
		if(client->progress_callback != NULL)
		{
			irecv_event_t event;
			event.progress = ((double) count/ (double) length) * 100.0;
			event.type = IRECV_PROGRESS;
			event.data = "Uploading";
			event.size = count;
			client->progress_callback(client, &event);
		}
		else
		{
			debug("Sent: %d bytes - %lu of %lu\n", bytes, count, length);
		}
	}
	
	if (dfuNotifyFinished && !recovery_mode)
	{
		irecv_control_transfer(client, 0x21, 1, 0, 0, (unsigned char*) buffer, 0, 1000);
		
		for (i = 0; i < 3; i++)
		{
			error = irecv_get_status(client, &status);
			if (error != IRECV_E_SUCCESS)
			{
				return error;
			}
		}
		irecv_reset(client);
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_receive(irecv_client_t client)
{
	char buffer[BUFFER_SIZE];
	memset(buffer, '\0', BUFFER_SIZE);
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	int bytes = 0;
	
	while (irecv_bulk_transfer(client, 0x81, (unsigned char*) buffer, BUFFER_SIZE, &bytes, 1000) == 0)
	{
		if (bytes > 0)
		{
			if (client->received_callback != NULL)
			{
				irecv_event_t event;
				event.size = bytes;
				event.data = buffer;
				event.type = IRECV_RECEIVED;
				if (client->received_callback(client, &event) != 0)
				{
					return IRECV_E_SUCCESS;
				}
			}
		}
		else
		{
			break;
		}
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_getenv(irecv_client_t client, const char* variable, char** value)
{
	int ret = 0;
	char command[256];
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	*value = NULL;
	
	if(variable == NULL)
	{
		return IRECV_E_UNKNOWN_ERROR;
	}
	
	memset(command, '\0', sizeof(command));
	snprintf(command, sizeof(command)-1, "getenv %s", variable);
	irecv_error_t error = irecv_send_command_raw(client, command);
	if(error == IRECV_E_PIPE)
	{
		return IRECV_E_SUCCESS;
	}
	if(error != IRECV_E_SUCCESS)
	{
		return error;
	}
	
	char* response = (char*) malloc(256);
	if (response == NULL)
	{
		return IRECV_E_OUT_OF_MEMORY;
	}
	
	memset(response, '\0', 256);
	ret = irecv_control_transfer(client, 0xC0, 0, 0, 0, (unsigned char*) response, 255, 1000);
	
	*value = response;
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_getret(irecv_client_t client, unsigned int* value)
{
	int ret = 0;
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	*value = 0;
	
	char* response = (char*) malloc(256);
	if (response == NULL)
	{
		return IRECV_E_OUT_OF_MEMORY;
	}
	
	memset(response, '\0', 256);
	ret = irecv_control_transfer(client, 0xC0, 0, 0, 0, (unsigned char*) response, 255, 1000);
	
	*value = ret;
	printf("irecv_getret: returning 0x%X\n", ret);
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_get_cpid(irecv_client_t client, unsigned int* cpid)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	char* cpid_string = strstr(client->serial, "CPID:");
	if (cpid_string == NULL)
	{
		*cpid = 0;
		return IRECV_E_UNKNOWN_ERROR;
	}
	sscanf(cpid_string, "CPID:%d", cpid);
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_get_bdid(irecv_client_t client, unsigned int* bdid)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	char* bdid_string = strstr(client->serial, "BDID:");
	if (bdid_string == NULL)
	{
		*bdid = 0;
		return IRECV_E_UNKNOWN_ERROR;
	}
	sscanf(bdid_string, "BDID:%d", bdid);
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_get_ecid(irecv_client_t client, unsigned long long* ecid)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	char* ecid_string = strstr(client->serial, "ECID:");
	if (ecid_string == NULL)
	{
		*ecid = 0;
		return IRECV_E_UNKNOWN_ERROR;
	}
	sscanf(ecid_string, "ECID:%qX", ecid);
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_send_exploit(irecv_client_t client)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	irecv_control_transfer(client, 0x21, 2, 0, 0, NULL, 0, 1000);
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_execute_script(irecv_client_t client, const char* filename)
{
	irecv_error_t error = IRECV_E_SUCCESS;
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	char* file_data = NULL;
	unsigned int file_size = 0;
	if(irecv_read_file(filename, &file_data, &file_size) < 0)
	{
		return IRECV_E_FILE_NOT_FOUND;
	}
	
	char* line = strtok(file_data, "\n");
	while(line != NULL)
	{
		if(line[0] != '#')
		{
			error = irecv_send_command(client, line);
			if(error != IRECV_E_SUCCESS)
			{
				return error;
			}
			
			error = irecv_receive(client);
			if(error != IRECV_E_SUCCESS)
			{
				return error;
			}
		}
		line = strtok(NULL, "\n");
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_saveenv(irecv_client_t client)
{
	irecv_error_t error = irecv_send_command_raw(client, "saveenv");
	if(error != IRECV_E_SUCCESS)
	{
		return error;
	}
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_setenv(irecv_client_t client, const char* variable, const char* value)
{
	char command[256];
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	if(variable == NULL || value == NULL)
	{
		return IRECV_E_UNKNOWN_ERROR;
	}
	
	memset(command, '\0', sizeof(command));
	snprintf(command, sizeof(command)-1, "setenv %s %s", variable, value);
	irecv_error_t error = irecv_send_command_raw(client, command);
	if(error != IRECV_E_SUCCESS)
	{
		return error;
	}
	
	return IRECV_E_SUCCESS;
}

const char* irecv_strerror(irecv_error_t error)
{
	switch (error)
	{
		case IRECV_E_SUCCESS:
			return "Command completed successfully";
			
		case IRECV_E_NO_DEVICE:
			return "Unable to find device";
			
		case IRECV_E_OUT_OF_MEMORY:
			return "Out of memory";
			
		case IRECV_E_UNABLE_TO_CONNECT:
			return "Unable to connect to device";
			
		case IRECV_E_INVALID_INPUT:
			return "Invalid input";
			
		case IRECV_E_FILE_NOT_FOUND:
			return "File not found";
			
		case IRECV_E_USB_UPLOAD:
			return "Unable to upload data to device";
			
		case IRECV_E_USB_STATUS:
			return "Unable to get device status";
			
		case IRECV_E_USB_INTERFACE:
			return "Unable to set device interface";
			
		case IRECV_E_USB_CONFIGURATION:
			return "Unable to set device configuration";
			
		case IRECV_E_PIPE:
			return "Broken pipe";
			
		case IRECV_E_TIMEOUT:
			return "Timeout talking to device";
			
		default:
			return "Unknown error";
	}
	
	return NULL;
}

int irecv_write_file(const char* filename, const void* data, size_t size)
{
	size_t bytes = 0;
	FILE* file = NULL;
	
	debug("Writing data to %s\n", filename);
	file = fopen(filename, "wb");
	if (file == NULL)
	{
		//error("read_file: Unable to open file %s\n", filename);
		return -1;
	}
	
	bytes = fwrite(data, 1, size, file);
	fclose(file);
	
	if (bytes != size)
	{
		//error("ERROR: Unable to write entire file: %s: %d of %d\n", filename, bytes, size);
		return -1;
	}
	
	return size;
}

int irecv_read_file(const char* filename, char** data, uint32_t* size)
{
	size_t bytes = 0;
	size_t length = 0;
	FILE* file = NULL;
	char* buffer = NULL;
	debug("Reading data from %s\n", filename);
	
	*size = 0;
	*data = NULL;
	
	file = fopen(filename, "rb");
	if (file == NULL)
	{
		//error("read_file: File %s not found\n", filename);
		return -1;
	}
	
	fseek(file, 0, SEEK_END);
	length = ftell(file);
	rewind(file);
	
	buffer = (char*) malloc(length);
	if(buffer == NULL)
	{
		//error("ERROR: Out of memory\n");
		fclose(file);
		return -1;
	}
	bytes = fread(buffer, 1, length, file);
	fclose(file);
	
	if(bytes != length)
	{
		//error("ERROR: Unable to read entire file\n");
		free(buffer);
		return -1;
	}
	
	*size = length;
	*data = buffer;
	return 0;
}

irecv_error_t irecv_reset_counters(irecv_client_t client)
{
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	if (client->mode == kDfuMode)
	{
		irecv_control_transfer(client, 0x21, 4, 0, 0, 0, 0, 1000);
	}
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_recv_buffer(irecv_client_t client, char* buffer, unsigned long length)
{
	//irecv_error_t error = IRECV_E_SUCCESS;
	int recovery_mode = (client->mode != kDfuMode);
	
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	int packet_size = recovery_mode ? 0x2000: 0x800;
	int last = length % packet_size;
	int packets = length / packet_size;
	if (last != 0)
	{
		packets++;
	}
	else
	{
		last = packet_size;
	}
	
	int i = 0;
	int bytes = 0;
	//double progress = 0;
	unsigned long count = 0;
	//unsigned int status = 0;
	for (i = 0; i < packets; i++)
	{
		unsigned short size = (i+1) < packets ? packet_size : last;
		bytes = irecv_control_transfer(client, 0xA1, 2, 0, 0, (unsigned char*)(buffer + i * packet_size), size, 1000);
		
		if (bytes != size)
		{
			return IRECV_E_USB_UPLOAD;
		}
		
		count += size;
		if(client->progress_callback != NULL)
		{
			irecv_event_t event;
			event.progress = ((double) count/ (double) length) * 100.0;
			event.type = IRECV_PROGRESS;
			event.data = "Downloading";
			event.size = count;
			client->progress_callback(client, &event);
		}
		else
		{
			debug("Sent: %d bytes - %lu of %lu\n", bytes, count, length);
		}
	}
	
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_finish_transfer(irecv_client_t client)
{
	int i = 0;
	unsigned int status = 0;
	
	if (check_context(client) != IRECV_E_SUCCESS) return IRECV_E_NO_DEVICE;
	
	irecv_control_transfer(client, 0x21, 1, 0, 0, 0, 0, 1000);
	
	for(i = 0; i < 3; i++)
	{
		irecv_get_status(client, &status);
	}
	irecv_reset(client);
	return IRECV_E_SUCCESS;
}

irecv_error_t irecv_get_device(irecv_client_t client, irecv_device_t* device)
{
	int device_id = DEVICE_UNKNOWN;
	uint32_t bdid = 0;
	uint32_t cpid = 0;
	
	if (irecv_get_cpid(client, &cpid) < 0)
	{
		return IRECV_E_UNKNOWN_ERROR;
	}
	
	switch (cpid)
	{
		case CPID_IPHONE2G:
			// iPhone1,1 iPhone1,2 and iPod1,1 all share the same ChipID
			//   so we need to check the BoardID
			if (irecv_get_bdid(client, &bdid) < 0)
			{
				break;
			}
			switch (bdid)
		{
			case BDID_IPHONE2G:
				device_id = DEVICE_IPHONE2G;
				break;
				
			case BDID_IPHONE3G:
				device_id = DEVICE_IPHONE3G;
				break;
				
			case BDID_IPOD1G:
				device_id = DEVICE_IPOD1G;
				break;
				
			default:
				device_id = DEVICE_UNKNOWN;
				break;
		}
			break;
			
		case CPID_IPHONE3GS:
			device_id = DEVICE_IPHONE3GS;
			break;
			
		case CPID_IPOD2G:
			device_id = DEVICE_IPOD2G;
			break;
			
		case CPID_IPOD3G:
			device_id = DEVICE_IPOD3G;
			break;
			
		case CPID_IPAD1G:
			// iPhone3,1 iPad4,1 and iPad1,1 all share the same ChipID
			//   so we need to check the BoardID
			if (irecv_get_bdid(client, &bdid) < 0)
			{
				break;
			}
			switch (bdid)
		{
			case BDID_IPAD1G:
				device_id = DEVICE_IPAD1G;
				break;
				
			case BDID_IPHONE4:
				device_id = DEVICE_IPHONE4;
				break;
				
			case BDID_IPHONE42:
				device_id = DEVICE_IPHONE42;
				break;
				
			case BDID_IPOD4G:
				device_id = DEVICE_IPOD4G;
				break;
				
			case BDID_APPLETV2:
				device_id = DEVICE_APPLETV2;
				break;
				
			default:
				device_id = DEVICE_UNKNOWN;
				break;
		}
			break;
			
		default:
			device_id = DEVICE_UNKNOWN;
			break;
    }
    
    //DEVICE_UNKNOWN=-1
    if (device_id == DEVICE_UNKNOWN)
    {
		*device = NULL;
		return IRECV_E_NO_DEVICE;
    }
	
	*device = &irecv_devices[device_id];
	return IRECV_E_SUCCESS;
}

irecv_client_t irecv_reconnect(irecv_client_t client, int initial_pause)
{
	irecv_error_t error = IRECV_E_SUCCESS;
	irecv_client_t new_client = NULL;
	irecv_event_cb_t progress_callback = client->progress_callback;
	
	if (check_context(client) == IRECV_E_SUCCESS)
	{
		irecv_close(client);
	}
	
	if (initial_pause > 0)
	{
		debug("Waiting %d seconds for the device to pop up...\n", initial_pause);
		sleep(initial_pause);
	}
	
	error = irecv_open_attempts(&new_client, 10);
	if(error != IRECV_E_SUCCESS)
	{
		return NULL;
	}
	
	new_client->progress_callback = progress_callback;
	return new_client;
}

void irecv_hexdump(unsigned char* buf, unsigned int len, unsigned int addr)
{
	int i, j;
	printf("0x%08x: ", addr);
	for (i = 0; i < len; i++)
	{
		if (i % 16 == 0 && i != 0)
		{
			for (j=i-16; j < i; j++)
			{
				unsigned char car = buf[j];
				if (car < 0x20 || car > 0x7f) car = '.';
				printf("%c", car);
			}
			printf("\n");
			addr += 0x10;
			printf("0x%08x: ", addr);
		}
		printf("%02x ", buf[i]);
	}
	
	int done = (i % 16);
	int remains = 16 - done;
	if (done > 0)
	{
		for (j = 0; j < remains; j++)
		{
			printf("	 ");
		}
	}
	
	if ((i - done) >= 0)
	{
		if (done == 0 && i > 0) done = 16;
		for (j = (i - done); j < i; j++)
		{
			unsigned char car = buf[j];
			if (car < 0x20 || car > 0x7f) car = '.';
			printf("%c", car);
		}
	}
	printf("\n");
}
