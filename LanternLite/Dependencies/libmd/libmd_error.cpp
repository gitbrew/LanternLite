#include "libMobiledevice.h"

void print_error(int error) 
{
	int err = error != 0 ? error : errno;

	Log(LOG_ERROR, "Error 0x%X (%i): '%s'", err, err, strerror(err));
}