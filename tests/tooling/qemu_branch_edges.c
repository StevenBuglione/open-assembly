/* Test-only QEMU plugin. Record executed PC pairs in one candidate section. */
#include <qemu-plugin.h>

#include <errno.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

enum { EDGE_SLOTS = 16384 };

static struct edge {
    uint64_t from, to;
} edges[EDGE_SLOTS];
static uint64_t start, end, previous, instructions;
static const char *output_path;
static atomic_bool unsupported_vcpu;
static bool overflow;

static void executed(unsigned int cpu, void *address)
{
    if (cpu != 0) {
        atomic_store_explicit(&unsupported_vcpu, true, memory_order_relaxed);
        return;
    }

    uint64_t pc = (uintptr_t)address;
    ++instructions;
    if (previous && !overflow) {
        size_t index = (previous * UINT64_C(2654435761) ^ pc) % EDGE_SLOTS;
        size_t first = index;
        while (edges[index].from &&
               (edges[index].from != previous || edges[index].to != pc)) {
            index = (index + 1) % EDGE_SLOTS;
            if (index == first) {
                overflow = true;
                break;
            }
        }
        if (!overflow)
            edges[index] = (struct edge){previous, pc};
    }
    previous = pc;
}

static void translated(struct qemu_plugin_tb *block, void *data)
{
    (void)data;
    for (size_t i = 0; i < qemu_plugin_tb_n_insns(block); ++i) {
        struct qemu_plugin_insn *instruction = qemu_plugin_tb_get_insn(block, i);
        uint64_t pc = qemu_plugin_insn_vaddr(instruction);
        if (start <= pc && pc < end)
            qemu_plugin_register_vcpu_insn_exec_cb(instruction, executed, QEMU_PLUGIN_CB_NO_REGS,
                                                   (void *)(uintptr_t)pc);
    }
}

static void completed(void *data)
{
    (void)data;
    FILE *report = fopen(output_path, "w");
    if (!report)
        return;
    if (!overflow && !atomic_load_explicit(&unsupported_vcpu, memory_order_relaxed)) {
        fprintf(report, "instructions %" PRIu64 "\n", instructions);
        for (size_t i = 0; i < EDGE_SLOTS; ++i) {
            if (edges[i].from)
                fprintf(report, "edge %" PRIx64 " %" PRIx64 "\n", edges[i].from, edges[i].to);
        }
        fputs("complete\n", report);
    }
    fclose(report);
}

static uint64_t read_address(const char *argument, const char *key)
{
    size_t length = strlen(key);
    if (strncmp(argument, key, length))
        return 0;
    char *suffix;
    errno = 0;
    unsigned long long value = strtoull(argument + length, &suffix, 16);
    return errno || suffix == argument + length || *suffix ? 0 : value;
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id, const qemu_info_t *info,
                                           int argc, char **argv)
{
    if (argc != 3 || info->system_emulation || strcmp(info->target_name, "x86_64"))
        return -1;
    start = read_address(argv[0], "start=");
    end = read_address(argv[1], "end=");
    if (!start || end <= start || strncmp(argv[2], "output=", 7) || !argv[2][7])
        return -1;
    output_path = argv[2] + 7;
    qemu_plugin_register_vcpu_tb_trans_cb(id, translated, NULL);
    qemu_plugin_register_atexit_cb(id, completed, NULL);
    return 0;
}
