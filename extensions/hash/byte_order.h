// Modified from code at https://github.com/rhash/RHash

/* byte_order.h */
#ifndef BYTE_ORDER_H
#define BYTE_ORDER_H
// #include "ustd.h"
@import Darwin.C.stdlib;

#if defined(__GLIBC__)
# include <endian.h>
#endif
#if defined(__FreeBSD__) || defined(__DragonFly__) || defined(__APPLE__)
@import Darwin.POSIX.sys.types;
#elif defined (__NetBSD__) || defined(__OpenBSD__)
# include <sys/param.h>
#endif


#ifdef __cplusplus
extern "C" {
#endif

/* if x86 compatible cpu */
#if defined(i386) || defined(__i386__) || defined(__i486__) || \
    defined(__i586__) || defined(__i686__) || defined(__pentium__) || \
    defined(__pentiumpro__) || defined(__pentium4__) || \
    defined(__nocona__) || defined(prescott) || defined(__core2__) || \
    defined(__k6__) || defined(__k8__) || defined(__athlon__) || \
    defined(__amd64) || defined(__amd64__) || \
    defined(__x86_64) || defined(__x86_64__) || defined(_M_IX86) || \
    defined(_M_AMD64) || defined(_M_IA64) || defined(_M_X64)
/* detect if x86-64 instruction set is supported */
# if defined(_LP64) || defined(__LP64__) || defined(__x86_64) || \
    defined(__x86_64__) || defined(_M_AMD64) || defined(_M_X64)
#  define CPU_X64
# else
#  define CPU_IA32
# endif
#endif

#define RHASH_BYTE_ORDER_LE 1234
#define RHASH_BYTE_ORDER_BE 4321

#if (defined(__BYTE_ORDER) && defined(__LITTLE_ENDIAN) && __BYTE_ORDER == __LITTLE_ENDIAN) || \
    (defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#  define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_LE
#elif (defined(__BYTE_ORDER) && defined(__BIG_ENDIAN) && __BYTE_ORDER == __BIG_ENDIAN) || \
      (defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#  define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_BE
#elif defined(_BYTE_ORDER)
#  if defined(_LITTLE_ENDIAN) && (_BYTE_ORDER == _LITTLE_ENDIAN)
#    define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_LE
#  elif defined(_BIG_ENDIAN) && (_BYTE_ORDER == _BIG_ENDIAN)
#    define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_BE
#  endif
#elif defined(__sun) && defined(_LITTLE_ENDIAN)
#  define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_LE
#elif defined(__sun) && defined(_BIG_ENDIAN)
#  define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_BE
#endif

/* try detecting endianness by CPU */
#ifdef RHASH_BYTE_ORDER
#elif defined(CPU_IA32) || defined(CPU_X64) || defined(__ia64) || defined(__ia64__) || \
      defined(__alpha__) || defined(_M_ALPHA) || defined(vax) || defined(MIPSEL) || \
      defined(_ARM_) || defined(__arm__) || defined(_M_ARM64) || defined(_M_ARM64EC)
#  define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_LE
#elif defined(__sparc) || defined(__sparc__) || defined(sparc) || \
      defined(_ARCH_PPC) || defined(_ARCH_PPC64) || defined(_POWER) || \
      defined(__POWERPC__) || defined(POWERPC) || defined(__powerpc) || \
      defined(__powerpc__) || defined(__powerpc64__) || defined(__ppc__) || \
      defined(__hpux)  || defined(_MIPSEB) || defined(mc68000) || \
      defined(__s390__) || defined(__s390x__) || defined(sel) || defined(__hppa__)
# define RHASH_BYTE_ORDER RHASH_BYTE_ORDER_BE
#else
#  error "Can't detect CPU architechture"
#endif

#define IS_BIG_ENDIAN (RHASH_BYTE_ORDER == RHASH_BYTE_ORDER_BE)
#define IS_LITTLE_ENDIAN (RHASH_BYTE_ORDER == RHASH_BYTE_ORDER_LE)

#ifndef __has_builtin
# define __has_builtin(x) 0
#endif

#define IS_ALIGNED_32(p) (0 == (3 & (uintptr_t)(p)))
#define IS_ALIGNED_64(p) (0 == (7 & (uintptr_t)(p)))

#if defined(_MSC_VER)
#define ALIGN_ATTR(n) __declspec(align(n))
#elif defined(__GNUC__)
#define ALIGN_ATTR(n) __attribute__((aligned (n)))
#else
#define ALIGN_ATTR(n) /* nothing */
#endif


#if defined(_MSC_VER) || defined(__BORLANDC__)
#define I64(x) x##ui64
#else
#define I64(x) x##ULL
#endif

#if defined(_MSC_VER)
#define RHASH_INLINE __inline
#elif defined(__GNUC__) && !defined(__STRICT_ANSI__)
#define RHASH_INLINE inline
#elif defined(__GNUC__)
#define RHASH_INLINE __inline__
#else
#define RHASH_INLINE
#endif

/* define rhash_ctz - count traling zero bits */
#if (defined(__GNUC__) && __GNUC__ >= 4 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4)) || \
    (defined(__clang__) && __has_builtin(__builtin_ctz))
/* GCC >= 3.4 or clang */
# define rhash_ctz(x) __builtin_ctz(x)
#else
unsigned rhash_ctz(unsigned); /* define as function */
#endif

void rhash_swap_copy_str_to_u32(void* to, int index, const void* from, size_t length);
void rhash_swap_copy_str_to_u64(void* to, int index, const void* from, size_t length);
void rhash_swap_copy_u64_to_str(void* to, const void* from, size_t length);
void rhash_u32_mem_swap(unsigned* p, int length_in_u32);

/* bswap definitions */
#if (defined(__GNUC__) && (__GNUC__ >= 4) && (__GNUC__ > 4 || __GNUC_MINOR__ >= 3)) || \
    (defined(__clang__) && __has_builtin(__builtin_bswap32) && __has_builtin(__builtin_bswap64))
/* GCC >= 4.3 or clang */
# define bswap_32(x) __builtin_bswap32(x)
# define bswap_64(x) __builtin_bswap64(x)
#elif (_MSC_VER > 1300) && (defined(CPU_IA32) || defined(CPU_X64)) /* MS VC */
# define bswap_32(x) _byteswap_ulong((unsigned long)x)
# define bswap_64(x) _byteswap_uint64((__int64)x)
#else
/* fallback to generic bswap definition */
static RHASH_INLINE uint32_t bswap_32(uint32_t x)
{
# if defined(__GNUC__) && defined(CPU_IA32) && !defined(__i386__) && !defined(RHASH_NO_ASM)
    __asm("bswap\t%0" : "=r" (x) : "0" (x)); /* gcc x86 version */
    return x;
# else
    x = ((x << 8) & 0xFF00FF00u) | ((x >> 8) & 0x00FF00FFu);
    return (x >> 16) | (x << 16);
# endif
}
static RHASH_INLINE uint64_t bswap_64(uint64_t x)
{
    union {
        uint64_t ll;
        uint32_t l[2];
    } w, r;
    w.ll = x;
    r.l[0] = bswap_32(w.l[1]);
    r.l[1] = bswap_32(w.l[0]);
    return r.ll;
}
#endif /* bswap definitions */

#if IS_BIG_ENDIAN
# define be2me_32(x) (x)
# define be2me_64(x) (x)
# define le2me_32(x) bswap_32(x)
# define le2me_64(x) bswap_64(x)

# define be32_copy(to, index, from, length) memcpy((char*)(to) + (index), (from), (length))
# define le32_copy(to, index, from, length) rhash_swap_copy_str_to_u32((to), (index), (from), (length))
# define be64_copy(to, index, from, length) memcpy((char*)(to) + (index), (from), (length))
# define le64_copy(to, index, from, length) rhash_swap_copy_str_to_u64((to), (index), (from), (length))
# define me64_to_be_str(to, from, length) memcpy((to), (from), (length))
# define me64_to_le_str(to, from, length) rhash_swap_copy_u64_to_str((to), (from), (length))

#else /* IS_BIG_ENDIAN */
# define be2me_32(x) bswap_32(x)
# define be2me_64(x) bswap_64(x)
# define le2me_32(x) (x)
# define le2me_64(x) (x)

# define be32_copy(to, index, from, length) rhash_swap_copy_str_to_u32((to), (index), (from), (length))
# define le32_copy(to, index, from, length) memcpy((char*)(to) + (index), (from), (length))
# define be64_copy(to, index, from, length) rhash_swap_copy_str_to_u64((to), (index), (from), (length))
# define le64_copy(to, index, from, length) memcpy((char*)(to) + (index), (from), (length))
# define me64_to_be_str(to, from, length) rhash_swap_copy_u64_to_str((to), (from), (length))
# define me64_to_le_str(to, from, length) memcpy((to), (from), (length))
#endif /* IS_BIG_ENDIAN */

/* ROTL/ROTR macros rotate a 32/64-bit word left/right by n bits */
#define ROTL32(dword, n) ((dword) << (n) ^ ((dword) >> (32 - (n))))
#define ROTR32(dword, n) ((dword) >> (n) ^ ((dword) << (32 - (n))))
#define ROTL64(qword, n) ((qword) << (n) ^ ((qword) >> (64 - (n))))
#define ROTR64(qword, n) ((qword) >> (n) ^ ((qword) << (64 - (n))))

#define CPU_FEATURE_SSE4_2 (52)

#if defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3)) \
    && (defined(CPU_X64) || defined(CPU_IA32))
# define HAS_INTEL_CPUID
int has_cpu_feature(unsigned feature_bit);
#else
# define has_cpu_feature(x) (0)
#endif

#ifdef __cplusplus
} /* extern "C" */
#endif /* __cplusplus */

#endif /* BYTE_ORDER_H */
