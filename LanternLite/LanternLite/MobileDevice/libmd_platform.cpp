#include "libMobiledevice.h"

BOOL libmd_private_api_located = FALSE;

static void recv_signal(int sig)
{
	Log(LOG_ERROR, "Info: Signal received. (%d)", sig);

	fflush(stdout);
	signal(sig, SIG_DFL);
	raise(sig);
}

LIBMD_API LIBMD_ERROR libmd_platform_init() {
	signal(SIGABRT, recv_signal);
	signal(SIGILL, recv_signal);
	signal(SIGINT, recv_signal);
	signal(SIGSEGV, recv_signal);
	signal(SIGTERM, recv_signal);
	// always the case since those are exported
	libmd_private_api_located = TRUE;
	return LIBMD_ERR_SUCCESS;
}