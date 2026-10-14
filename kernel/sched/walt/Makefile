# SPDX-License-Identifier: GPL-2.0
# trace.o re-includes its local trace.h through TRACE_INCLUDE_PATH=.,
# so it needs its own directory on the search path (mainline convention
# for every trace-point user; required by stricter Clang header search).
CFLAGS_trace.o := -I$(src)
obj-$(CONFIG_SCHED_WALT) += walt.o boost.o sched_avg.o qc_vas.o core_ctl.o trace.o
obj-$(CONFIG_CPU_FREQ) += cpu-boost.o
