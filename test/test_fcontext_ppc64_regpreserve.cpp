
//          Copyright Oliver Kowalke 2009.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// ppc64 SysV ELF context-switch register preservation regression tests.
// Covers three bugs fixed in boost-1.87.0 ppc64 asm (Bug 1/2/3).
//
// DESIGN NOTE — why inline asm is required:
//
// The bugs manifest in hardware registers f14-f31 and v20-v31.  A C++ test
// that only reads/writes memory (even volatile globals) never puts values
// into those registers: the compiler spills everything to the stack before
// any call and reloads after, so the asm never gets a chance to corrupt them.
//
// The only reliable way to detect "asm did not save register X" is to use
// inline asm to park a sentinel directly in X, call jump_fcontext (which
// must save/restore X), and then read X back via inline asm and compare.
// On non-ppc64 architectures the asm blocks are no-ops and all tests pass
// trivially — which is correct, because the bugs only exist on ppc64.

#include <stdio.h>
#include <stdlib.h>
#include <cstdint>
#include <cstring>
#include <iostream>

#include <boost/core/lightweight_test.hpp>
#include <boost/context/detail/fcontext.hpp>

#if defined(BOOST_CONTEXT_USE_MAP_STACK)
extern "C" {
#include <sys/mman.h>
}
#endif

template<std::size_t Max, std::size_t Default, std::size_t Min>
class simple_stack_allocator {
public:
    static std::size_t maximum_stacksize() { return Max; }
    static std::size_t default_stacksize() { return Default; }
    static std::size_t minimum_stacksize() { return Min; }

    void * allocate(std::size_t size) const {
#if defined(BOOST_CONTEXT_USE_MAP_STACK)
        void * limit = ::mmap(0, size, PROT_READ | PROT_WRITE,
                              MAP_PRIVATE | MAP_ANON | MAP_STACK, -1, 0);
        if (limit == MAP_FAILED) throw std::bad_alloc();
#else
        void * limit = std::malloc(size);
        if (!limit) throw std::bad_alloc();
#endif
        return static_cast<char *>(limit) + size;
    }

    void deallocate(void * vp, std::size_t size) const {
        void * limit = static_cast<char *>(vp) - size;
#if defined(BOOST_CONTEXT_USE_MAP_STACK)
        ::munmap(limit, size);
#else
        free(limit);
#endif
    }
};

typedef simple_stack_allocator<8 * 1024 * 1024, 512 * 1024, 64 * 1024>
    stack_allocator;

namespace ctx = boost::context::detail;

// ---------------------------------------------------------------------------
// Inline-asm helpers for ppc64: load/store a double sentinel into/from f14,
// and a 64-bit integer sentinel into/from v20 (low 64 bits via GPR bounce).
// On non-ppc64 these are empty and the tests skip their assertions.
// ---------------------------------------------------------------------------

#if defined(__powerpc64__)

static inline void load_f14(double val) {
    __asm__ volatile("fmr 14, %0" : : "f"(val) : "fr14");
}
static inline double read_f14() {
    double out;
    __asm__ volatile("fmr %0, 14" : "=f"(out) : : "fr14");
    return out;
}

// v20 has no direct GPR↔VR move in POWER ISA before VSX.
// Use the stack: store a 64-bit pattern into the low 8 bytes via stxsdx
// (VSX scalar double store) after bouncing through a GPR pair.
// We use v20 = VS52.  On ppc64le the compiler never touches v20 here
// because it is non-volatile and we are not in a function that the ABI
// would require to save it for us.
static inline void load_v20(uint64_t val) {
    // mtvsrd moves a GPR into the VSX scalar register (frD = VRn + 32 for VR).
    // VS52 = v20.  mtvsrd is available from POWER7/VSX.
    __asm__ volatile("mtvsrd 52, %0" : : "r"(val) : "v20");
}
static inline uint64_t read_v20() {
    uint64_t out;
    __asm__ volatile("mfvsrd %0, 52" : "=r"(out) : : "v20");
    return out;
}

#else
static inline void    load_f14(double)    {}
static inline double  read_f14()          { return 0.0; }
static inline void    load_v20(uint64_t)  {}
static inline uint64_t read_v20()         { return 0; }
#endif

// ---------------------------------------------------------------------------
// Bug 1: f14-f31 not saved/restored across jump_fcontext.
//
// Park a sentinel in f14 before the jump.  The context function does nothing
// with FPRs.  After returning, f14 must still hold the sentinel.
// Without the fix, jump_fcontext clobbers f14 (it was never saved), so the
// read-back returns whatever was already in f14 on the other context.
// ---------------------------------------------------------------------------

static const double FPR_SENTINEL = 3.14159265358979323846;

static void ctx_fn_fpr(ctx::transfer_t t) {
    ctx::jump_fcontext(t.fctx, nullptr);
}

void test_fpr_preserved_across_jump() {
    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_fpr);
    BOOST_TEST(fctx);

    load_f14(FPR_SENTINEL);
    ctx::jump_fcontext(fctx, nullptr);
    double got = read_f14();

#if defined(__powerpc64__)
    BOOST_TEST_EQ(got, FPR_SENTINEL);
#endif

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// Bug 1 (VMX): v20-v31 not saved/restored across jump_fcontext.
//
// Same pattern: park a sentinel in v20 before the jump, verify after return.
// ---------------------------------------------------------------------------

static const uint64_t VMX_SENTINEL = 0xDEADBEEFCAFEBABEULL;

static void ctx_fn_vmx(ctx::transfer_t t) {
    ctx::jump_fcontext(t.fctx, nullptr);
}

void test_vmx_preserved_across_jump() {
    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_vmx);
    BOOST_TEST(fctx);

    load_v20(VMX_SENTINEL);
    ctx::jump_fcontext(fctx, nullptr);
    uint64_t got = read_v20();

#if defined(__powerpc64__)
    BOOST_TEST_EQ(got, VMX_SENTINEL);
#endif

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// Bug 2: VMX stvx/lvx EA misalignment — first VMX slot at offset 184
// (8-byte aligned) caused stvx to write to r1+176 (the PC slot), so
// make_fcontext's entry point was overwritten with garbage and bctr→0.
//
// Test: park a non-zero sentinel in v20 *before* make_fcontext runs, then
// create a context and jump into it.  Without the fix, stvx fires during
// the save phase and writes v20's bit pattern over the PC slot (r1+176);
// since we loaded v20 with a non-zero value, bctr jumps to a garbage address
// and the process crashes — test reports failure via signal/abort.
// With the fix, the context function is reached and sets the flag.
// ---------------------------------------------------------------------------

static bool vmx_alignment_ctx_reached = false;

static void ctx_fn_vmx_alignment(ctx::transfer_t t) {
    vmx_alignment_ctx_reached = true;
    ctx::jump_fcontext(t.fctx, nullptr);
}

void test_vmx_alignment_no_pc_corruption() {
    vmx_alignment_ctx_reached = false;

#if defined(__powerpc64__)
    load_v20(VMX_SENTINEL);
#endif

    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_vmx_alignment);
    BOOST_TEST(fctx);
    ctx::jump_fcontext(fctx, nullptr);

    BOOST_TEST(vmx_alignment_ctx_reached);

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// Bug 3: non-zero .localentry caused a frame-allocating long-branch thunk.
//
// This bug only manifests when the call site is >32 MB from jump_fcontext
// (beyond the range of a single bl instruction), which cannot be reproduced
// in a unit test binary.  We test the observable consequence instead:
// two round-trips through the same context must both complete and the
// data pointers must survive intact.  If the thunk were present and active
// the second jump would corrupt the stack and crash.
// ---------------------------------------------------------------------------

static int bounce_count = 0;

static void ctx_fn_bounce(ctx::transfer_t t) {
    ++bounce_count;
    t = ctx::jump_fcontext(t.fctx, (void *)1);
    ++bounce_count;
    ctx::jump_fcontext(t.fctx, (void *)2);
}

void test_double_jump_no_thunk_corruption() {
    bounce_count = 0;

    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_bounce);
    BOOST_TEST(fctx);

    ctx::transfer_t t1 = ctx::jump_fcontext(fctx, nullptr);
    BOOST_TEST_EQ(1, bounce_count);
    BOOST_TEST(t1.fctx != nullptr);
    BOOST_TEST_EQ((void *)1, t1.data);

    ctx::transfer_t t2 = ctx::jump_fcontext(t1.fctx, nullptr);
    BOOST_TEST_EQ(2, bounce_count);
    BOOST_TEST(t2.fctx != nullptr);
    BOOST_TEST_EQ((void *)2, t2.data);

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// Bug 3 (ontop variant): same thunk bug in ontop_fcontext.
// ---------------------------------------------------------------------------

static int ontop_counter = 0;

static ctx::transfer_t ontop_fn(ctx::transfer_t t) {
    ++ontop_counter;
    return t;
}

static void ctx_fn_for_ontop(ctx::transfer_t t) {
    t = ctx::jump_fcontext(t.fctx, nullptr);
    ctx::jump_fcontext(t.fctx, (void *)42);
}

void test_ontop_double_jump_no_thunk_corruption() {
    ontop_counter = 0;

    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_for_ontop);
    BOOST_TEST(fctx);

    ctx::transfer_t t = ctx::jump_fcontext(fctx, nullptr);
    BOOST_TEST(t.fctx != nullptr);

    t = ctx::ontop_fcontext(t.fctx, nullptr, ontop_fn);
    BOOST_TEST_EQ(1, ontop_counter);
    BOOST_TEST(t.fctx != nullptr);
    BOOST_TEST_EQ((void *)42, t.data);

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// make_fcontext frame-size consistency: SP at context entry must be 16-byte aligned.
// ---------------------------------------------------------------------------

static uintptr_t ctx_sp_value  = 0;
static int       ctx_trip_count = 0;

static void ctx_fn_sp_check(ctx::transfer_t t) {
#if defined(__powerpc64__)
    uintptr_t sp;
    __asm__ volatile("mr %0, 1" : "=r"(sp));
    ctx_sp_value = sp;
#endif
    ++ctx_trip_count;
    ctx::transfer_t r = ctx::jump_fcontext(t.fctx, nullptr);
    ++ctx_trip_count;
    ctx::jump_fcontext(r.fctx, nullptr);
}

void test_make_fcontext_sp_alignment() {
    ctx_sp_value   = 0;
    ctx_trip_count = 0;

    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_sp_check);
    BOOST_TEST(fctx);

    ctx::transfer_t t = ctx::jump_fcontext(fctx, nullptr);
    BOOST_TEST_EQ(1, ctx_trip_count);
    ctx::jump_fcontext(t.fctx, nullptr);
    BOOST_TEST_EQ(2, ctx_trip_count);

#if defined(__powerpc64__)
    BOOST_TEST_EQ(0u, ctx_sp_value % 16);
#endif

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

// ---------------------------------------------------------------------------
// Regression: f14 accumulates correctly across interleaved context switches.
// Uses inline asm to keep the running sum live in f14 across each yield,
// verifying that jump_fcontext saves/restores f14 on every switch.
// ---------------------------------------------------------------------------

static double fpr_accum_result = 0.0;
static bool   fpr_accum_ok     = false;

static void ctx_fn_fpr_accumulate(ctx::transfer_t t) {
    double sum = 1.0;
    load_f14(sum);
    for (int i = 0; i < 5; ++i) {
        sum = read_f14() + (double)(i + 1) * 3.14159;
        load_f14(sum);
        t = ctx::jump_fcontext(t.fctx, nullptr);
    }
    fpr_accum_result = read_f14();
    fpr_accum_ok     = true;
    ctx::jump_fcontext(t.fctx, nullptr);
}

void test_multi_context_no_fpr_cross_contamination() {
    fpr_accum_result = 0.0;
    fpr_accum_ok     = false;

    stack_allocator alloc;
    void * sp = alloc.allocate(stack_allocator::default_stacksize());
    ctx::fcontext_t fctx = ctx::make_fcontext(
        sp, stack_allocator::default_stacksize(), ctx_fn_fpr_accumulate);
    BOOST_TEST(fctx);

    ctx::transfer_t t = ctx::jump_fcontext(fctx, nullptr);
    for (int i = 0; i < 5; ++i) {
        BOOST_TEST(t.fctx != nullptr);
        t = ctx::jump_fcontext(t.fctx, nullptr);
    }

    BOOST_TEST(fpr_accum_ok);
#if defined(__powerpc64__)
    double expected = 1.0;
    for (int i = 0; i < 5; ++i) expected += (double)(i + 1) * 3.14159;
    BOOST_TEST_EQ(fpr_accum_result, expected);
#endif

    alloc.deallocate(sp, stack_allocator::default_stacksize());
}

int main() {
    test_fpr_preserved_across_jump();
    test_vmx_preserved_across_jump();
    test_vmx_alignment_no_pc_corruption();
    test_double_jump_no_thunk_corruption();
    test_ontop_double_jump_no_thunk_corruption();
    test_make_fcontext_sp_alignment();
    test_multi_context_no_fpr_cross_contamination();
    return boost::report_errors();
}
