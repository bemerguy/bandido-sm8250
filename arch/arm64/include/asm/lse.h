/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __ASM_LSE_H
#define __ASM_LSE_H

#if defined(CONFIG_AS_LSE) && defined(CONFIG_ARM64_LSE_ATOMICS)

#include <linux/compiler_types.h>
#include <linux/export.h>
#include <linux/stringify.h>
#include <asm/alternative.h>
#include <asm/cpucaps.h>

#ifdef __ASSEMBLER__

.arch_extension	lse

#else	/* __ASSEMBLER__ */

#if defined(CONFIG_LTO_CLANG) || defined(CONFIG_LTO_GCC)
#define __LSE_PREAMBLE	".arch armv8-a+lse\n"
#else
__asm__(".arch_extension	lse");
#define __LSE_PREAMBLE
#endif

#define ARM64_LSE_ATOMIC_INSN(lse)					\
	__LSE_PREAMBLE lse

#endif	/* __ASSEMBLER__ */
#else	/* CONFIG_AS_LSE && CONFIG_ARM64_LSE_ATOMICS */

#define ARM64_LSE_ATOMIC_INSN(lse) lse

#ifndef __ASSEMBLER__

#define __LL_SC_INLINE		static inline
#define __LL_SC_PREFIX(x)	x
#define __LL_SC_EXPORT(x)

#endif	/* __ASSEMBLER__ */
#endif	/* CONFIG_AS_LSE && CONFIG_ARM64_LSE_ATOMICS */
#endif	/* __ASM_LSE_H */
