@c
@c  Written by Eric Norum
@c
@c  COPYRIGHT (c) 1988-1998.
@c  On-Line Applications Research Corporation (OAR).
@c  All rights reserved.
@c
@c  $Id$
@c

@chapter Using networking in an RTEMS application

@section Makefile changes
@subsection Including the required managers
The KA9Q networking code requires several RTEMS managers
in the application:

@example
MANAGERS = io event semaphore
@end example

@subsection Increasing the size of the heap
The networking tasks allocate a lot of memory.  For most applications
the heap should be at least 256 kbytes.
The amount of memory set aside for the heap can be adjusted by setting
the @code{CFLAGS_LD} definition as shown below:

@example
CFLAGS_LD += -Wl,--defsym -Wl,HeapSize=0x80000
@end example

This sets aside 512 kbytes of memory for the heap.

@section System Configuration

The networking tasks allocate some RTEMS objects.  These
must be accounted for in the application configuration table.  The following
lists the requirements.

@table @b
@item TASKS
One network task plus a receive and transmit task for each device.

@item SEMAPHORES
One network semaphore plus one syslog mutex semaphore if the application uses
openlog/syslog.

@item EVENTS
The network stack uses @code{RTEMS_EVENT_24} and @code{RTEMS_EVENT_25}.
This has no effect on the application configuration, but
application tasks which call the network functions should not
use these events for other purposes.

@end table

@section Initialization
@subsection Additional include files
The source file which declares the network configuration
structures and calls the network initialization function must include

@example
#include <rtems_bsdnet.h>
@end example

@subsection Network configuration
The network configuration is specified by declaring
and initializing the @code{rtems_bsdnet_configuration}
structure.  This structure may be declared @code{const} since the
network initialization functions do not write to any of the entries.

The structure entries are described in the following table.
If your application uses BOOTP to obtain network configuration
information and if you are happy with the default values described
below, you need to provide only the first two entries in this structure.

@table @code

@item struct rtems_bsdnet_ifconfig *ifconfig
A pointer to the first configuration structure of the first network
device.  This structure is described in the following section.
You must provide a value for this entry since there is no default value for it.


@item void (*bootp)(void)
This entry should be set to @code{rtems_bsdnet_do_bootp}
if your application will use BOOTP to obtain network configuration information.
It should be set to @code{NULL}
if your application does not use BOOTP.


@item int network_task_priority 
The priority at which the network task and network device
receive and transmit tasks will run.
If a value of 0 is specified the tasks will run at priority 100.

@item unsigned long mbuf_bytecount
The number of bytes to allocate from the heap for use as mbufs.  
If a value of 0 is specified, 64 kbytes will be allocated.

@item unsigned long mbuf_cluster_bytecount
The number of bytes to allocate from the heap for use as mbuf clusters.  
If a value of 0 is specified, 128 kbytes will be allocated.

@item char *hostname
The host name of the system.
If this entry is @code{NULL} the host name,
and all the remaining values specified by the @code{rtems_bsdnet_configuration}
structure will be obtained from a BOOTP server.

@item char *domainname
The name of the Internet domain to which the system belongs.

@item char *gateway
The Internet host number of the network gateway machine,
specified in `dotted decimal' (@code{129.128.4.1}) form.

@item char *log_host
The Internet host number of the machine to which @code{syslog} messages
will be sent.

@item char *name_server
The Internet host number of up to three machines to be used as
Internet Domain Name Servers.

@end table

@example
rtems_task_set_priority (RTEMS_SELF, 30, &oldPri);
@end example

@subsection Network device configuration
Network devices are specified and configured by declaring and initializing a
@code{struct rtems_bsdnet_ifcontig} structure for each network device.
These structures may be declared @code{const} since the
network initialization functions do not write to any of the entries.

The structure entries are described in the following table.  An application
which uses a single network interface, gets network configuration information
from a BOOTP server, and uses the default values for all driver
parameters needs to initialize only the first two entries in the
structure.

@table @code
@item char *name
The full name of the network device.  This name consists of the
driver name and the unit number (e.g. @code{"scc1"}).

@item int (*attach)(struct rtems_bsdnet_ifconfig *conf)
The address of the driver @code{attach} function.   The network 
initialization function calls this function to configure the driver and
attach it to the network stack.

@item struct rtems_bsdnet_ifconfig *next
A pointer to the network device configuration structure for the next network 
interface, or @code{NULL} if this is the configuration structure of the
last network interface.

@item char *ip_address
The Internet address of the device,
specified in `dotted decimal' (@code{129.128.4.2}) form, or @code{NULL}
if the device configuration information is being obtained from a
BOOTP server.

@item char *ip_netmask
The Internet inetwork mask of the device,
specified in `dotted decimal' (@code{255.255.255.0}) form, or @code{NULL}
if the device configuration information is being obtained from a
BOOTP server.


@item void *hardware_address
The hardware address of the device, or @code{NULL} if the driver is
to obtain the hardware address in some other way (usually  by reading
it from the device or from the bootstrap ROM).

@item int ignore_broadcast
Zero if the device is to accept broadcast packets, non-zero if the device
is to ignore broadcast packets.

@item int mtu
The maximum transmission unit of the device, or zero if the driver
is to choose a default value (typically 1500 for Ethernet devices).

@item int rbuf_count
The number of receive buffers to use, or zero if the driver is to
choose a default value

@item int xbuf_count
The number of transmit buffers to use, or zero if the driver is to
choose a default value
Keep in mind that some network devices may use 4 or more
transmit descriptors for a single transmit buffer.

@end table


@subsection Network initialization
The networking tasks must be started before any
network I/O operations can be performed.  This is done by calling:
@example
rtems_bsdnet_initialize_network ();
@end example


@section Application code
The RTEMS network package provides almost a complete set of BSD network
services.  The network functions work like their BSD counterparts
with the following exceptions:

@itemize
@item A given socket can be read or written by only one task at a time.
@item There is no @code{select} function.
@item You must call @code{openlog} before calling any of the @code{syslog} functions.
@item @b{Some of the network functions are not thread-safe.}
For example the following functions return a pointer to a static
buffer which remains valid only until the next call:

@table @code
@item gethostbyaddr
@item gethostbyname
@item inet_ntoa
(@code{inet_ntop} is thread-safe, though).
@end table
@end itemize

@subsection Network statistics
There are a number of functions to print statistics gathered by the network stack:
@table @code
@item rtems_bsdnet_show_if_stats
Display statistics gathered by network interfaces.

@item rtems_bsdnet_show_ip_stats
Display IP packet statistics.

@item rtems_bsdnet_show_icmp_stats
Display ICMP packet statistics.

@item rtems_bsdnet_show_tcp_stats
Display TCP packet statistics.

@item rtems_bsdnet_show_udp_stats
Display UDP packet statistics.

@item rtems_bsdnet_show_mbuf_stats
Display mbuf statistics.

@item rtems_bsdnet_show_inet_routes
Display the routing table.

@end table
