/* Observe the guest CPU state used by the independent copy checks. */
#include <glib.h>
#include <qemu-plugin.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

static struct qemu_plugin_register *rax, *rcx;
static bool have_rax, have_rcx, clear_ymm;
static uint64_t cpuid_pc, xstate_pc;
static const char *output;
static unsigned cpuid_count, xstate_count, cleared;
static unsigned feature_bits, xstate_bits;

static void registers(unsigned vcpu, void *data)
{
    (void)vcpu;
    (void)data;
    GArray *list = qemu_plugin_get_registers();
    for (unsigned i = 0; i < list->len; ++i) {
        qemu_plugin_reg_descriptor info = g_array_index(list, qemu_plugin_reg_descriptor, i);
        if ((!strcmp(info.name, "rax") || !strcmp(info.name, "eax")) && !info.is_readonly) {
            rax = info.handle;
            have_rax = true;
        } else if (!strcmp(info.name, "rcx") || !strcmp(info.name, "ecx")) {
            rcx = info.handle;
            have_rcx = true;
        }
    }
    g_array_free(list, true);
}

static unsigned low_dword(const GByteArray *bytes)
{
    return (unsigned)bytes->data[0] | (unsigned)bytes->data[1] << 8 |
           (unsigned)bytes->data[2] << 16 | (unsigned)bytes->data[3] << 24;
}

static void features(unsigned vcpu, void *data)
{
    (void)vcpu;
    (void)data;
    GByteArray *bytes = g_byte_array_sized_new(8);
    if (have_rcx && qemu_plugin_read_register(rcx, bytes) && bytes->len >= 4) {
        ++cpuid_count;
        feature_bits = low_dword(bytes);
    }
    g_byte_array_unref(bytes);
}

static void xstate(unsigned vcpu, void *data)
{
    (void)vcpu;
    (void)data;
    GByteArray *bytes = g_byte_array_sized_new(8);
    if (have_rax && qemu_plugin_read_register(rax, bytes) && bytes->len >= 4) {
        ++xstate_count;
        xstate_bits = low_dword(bytes);
        if (clear_ymm && (xstate_bits & 6) == 6) {
            bytes->data[0] &= ~4U;
            if (qemu_plugin_write_register(rax, bytes))
                ++cleared;
        }
    }
    g_byte_array_unref(bytes);
}

static void translate(struct qemu_plugin_tb *block, void *data)
{
    (void)data;
    for (size_t i = 0; i < qemu_plugin_tb_n_insns(block); ++i) {
        struct qemu_plugin_insn *instruction = qemu_plugin_tb_get_insn(block, i);
        uint64_t pc = qemu_plugin_insn_vaddr(instruction);
        if (pc == cpuid_pc)
            qemu_plugin_register_vcpu_insn_exec_cb(instruction, features, QEMU_PLUGIN_CB_R_REGS, NULL);
        if (pc == xstate_pc)
            qemu_plugin_register_vcpu_insn_exec_cb(instruction, xstate, QEMU_PLUGIN_CB_RW_REGS, NULL);
    }
}

static void finish(void *data)
{
    (void)data;
    FILE *file = fopen(output, "w");
    if (file) {
        fprintf(file, "%u %08x %u %08x %u\n", cpuid_count, feature_bits, xstate_count, xstate_bits, cleared);
        fclose(file);
    }
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id, const qemu_info_t *info, int count, char **args)
{
    if (!info || strcmp(info->target_name, "x86_64") || count != 4 ||
        strncmp(args[0], "cpuid=", 6) || strncmp(args[1], "xstate=", 7) ||
        strncmp(args[2], "clear=", 6) || strncmp(args[3], "output=", 7))
        return -1;
    cpuid_pc = strtoull(args[0] + 6, NULL, 16);
    xstate_pc = strtoull(args[1] + 7, NULL, 16);
    clear_ymm = !strcmp(args[2] + 6, "1");
    output = args[3] + 7;
    qemu_plugin_register_vcpu_init_cb(id, registers, NULL);
    qemu_plugin_register_vcpu_tb_trans_cb(id, translate, NULL);
    qemu_plugin_register_atexit_cb(id, finish, NULL);
    return 0;
}
