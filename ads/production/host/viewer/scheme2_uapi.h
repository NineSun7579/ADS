#pragma once
#include <linux/types.h>
#include <linux/ioctl.h>
// Fixed version-1 ABI; candidate driver peer supplies the 8 MiB allocator.
struct pz_export_rx { __u32 version, flags, reserved[2]; };
struct pz_lease {
    __u32 version, flags, offset, length;
    __aligned_u64 token;
    __u32 reserved[4];
};
#define PZ_EXPORT_RX _IOW(0x53, 0x30, struct pz_export_rx)
#define PZ_BEGIN _IOWR(0x53, 0x31, struct pz_lease)
#define PZ_END _IOW(0x53, 0x32, struct pz_lease)
static_assert(sizeof(pz_lease) == 40, "driver ABI");
