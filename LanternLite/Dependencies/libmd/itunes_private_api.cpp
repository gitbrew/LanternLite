#include "libMobiledevice.h"

extern "C" {
	int AMRecoveryModeDeviceSendFileToDevice(AMRecoveryModeDevice device, CFStringRef fileName);
	int AMRecoveryModeDeviceSendCommandToDevice(AMRecoveryModeDevice device, CFStringRef command);
}


LIBMD_API int call_AMRecoveryModeDeviceSendFileToDevice(AMRecoveryModeDevice device, const char* fileName)
{
	CFStringRef cfstrFilename = __CFStringMakeConstantString(fileName);
	return AMRecoveryModeDeviceSendFileToDevice(device, cfstrFilename);
}


LIBMD_API int libmd_builtin_uploadFile(AMRecoveryModeDevice device, const char* fileName)
{
	return call_AMRecoveryModeDeviceSendFileToDevice(device, fileName);
}

LIBMD_API int libmd_builtin_sendCommand(AMRecoveryModeDevice device, const char* cmd)
{
	CFStringRef cfstrCmd = __CFStringMakeConstantString(cmd);
	return AMRecoveryModeDeviceSendCommandToDevice(device, cfstrCmd);	
	
}

LIBMD_API int libmd_builtin_uploadFileDfu(AMRecoveryModeDevice device, const char* fileName)
{
	return call_AMRecoveryModeDeviceSendFileToDevice(device, fileName);	
}

LIBMD_API int libmd_builtin_uploadUsbExploit(AMRecoveryModeDevice device, const char* fileName)
{
	return -1;
}
