"""Read and validate the Open Assembly source contracts."""

from dataclasses import dataclass
import hashlib
from pathlib import Path, PurePosixPath
import re
import tomllib


ROOT = Path(__file__).resolve().parent.parent
IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_]*"
HEADER = r"[a-z][a-z0-9_]*(?:/[a-z][a-z0-9_]*)*\.h"
STANDARD = r"(?:C17 7(?:\.[0-9]+)+|POSIX\.1-2024 (?:XBD|XSH) [A-Za-z0-9_./<>-]+|Runtime ABI [A-Za-z0-9_<>.]+|Extension ABI [A-Za-z0-9_<>./]+)"
C17_HEADERS = dict(zip(
    ("assert complex ctype errno fenv float inttypes iso646 limits locale math "
     "setjmp signal stdalign stdarg stdatomic stdbool stddef stdint stdio stdlib "
     "stdnoreturn string tgmath threads time uchar wchar wctype").split(),
    range(2, 31),
    strict=True,
))
KINDS = ("functions", "macros", "types", "constants", "pragmas", "generic_functions", "families", "objects")
UPSTREAMS = {
    "musl": "https://git.musl-libc.org/cgit/musl",
    "fdlibm": "https://www.netlib.org/fdlibm",
    "Ryu": "https://github.com/ulfjack/ryu",
    "CORE-MATH": "https://gitlab.inria.fr/core-math/core-math",
    "ARM optimized-routines": "https://github.com/ARM-software/optimized-routines",
}
LICENSES = {"MIT", "BSD-2-Clause", "BSD-3-Clause", "CC0-1.0", "Apache-2.0", "BSL-1.0", "LicenseRef-fdlibm"}
C17_SOURCE = "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf"
POSIX_SOURCE = "https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/unistd.h.html"
POSIX_FDS = {"STDIN_FILENO": 0, "STDOUT_FILENO": 1, "STDERR_FILENO": 2}
FILE_TYPES = {"off_t": "long", "mode_t": "unsigned int", "uid_t": "unsigned int", "gid_t": "unsigned int"}
ACCESS_MODES = {"F_OK", "R_OK", "W_OK", "X_OK"}
SYSCONF_NAMES = {"_SC_PAGESIZE", "_SC_PAGE_SIZE"}
MMAP_POSIX = {"PROT_NONE", "PROT_READ", "PROT_WRITE", "PROT_EXEC",
              "MAP_SHARED", "MAP_PRIVATE", "MAP_FIXED", "MAP_ANONYMOUS"}
MMAP_LINUX = {"MAP_SHARED_VALIDATE", "MAP_FIXED_NOREPLACE",
              "MREMAP_MAYMOVE", "MREMAP_FIXED", "MREMAP_DONTUNMAP"}
SEEK_ORIGINS = {"SEEK_SET", "SEEK_CUR", "SEEK_END"}
OPEN_FLAGS = {"AT_FDCWD", "AT_SYMLINK_NOFOLLOW", "O_RDONLY", "O_WRONLY", "O_RDWR", "O_ACCMODE", "O_CREAT",
              "O_EXCL", "O_NOCTTY", "O_TRUNC", "O_APPEND", "O_NONBLOCK", "O_DSYNC",
              "O_DIRECTORY", "O_NOFOLLOW", "O_CLOEXEC", "O_SYNC"}
FCNTL_POSIX = {
    "F_DUPFD", "F_DUPFD_CLOEXEC", "F_GETFD", "F_SETFD", "F_GETFL", "F_SETFL",
    "F_GETLK", "F_SETLK", "F_SETLKW", "F_OFD_GETLK", "F_OFD_SETLK", "F_OFD_SETLKW",
    "F_GETOWN", "F_SETOWN", "F_GETOWN_EX", "F_SETOWN_EX", "F_RDLCK", "F_WRLCK",
    "F_UNLCK", "F_OWNER_PID", "F_OWNER_PGRP", "FD_CLOEXEC",
}
FCNTL_LINUX = {"F_GETPIPE_SZ", "F_SETPIPE_SZ", "F_OWNER_TID"}
MODE_BITS = {"S_IRWXU", "S_IRUSR", "S_IWUSR", "S_IXUSR", "S_IRWXG", "S_IRGRP",
             "S_IWGRP", "S_IXGRP", "S_IRWXO", "S_IROTH", "S_IWOTH", "S_IXOTH",
             "S_ISUID", "S_ISGID", "S_ISVTX"}
STAT_FILE_KINDS = {"FIFO": "S_IFIFO", **{kind: "S_IF" + kind for kind in
                                       ("CHR", "DIR", "BLK", "REG", "LNK", "SOCK")}}
STAT_MODE_BITS = {"S_IFMT", *STAT_FILE_KINDS.values()}
DIRENT_TYPES = {"DT_UNKNOWN", "DT_FIFO", "DT_CHR", "DT_DIR", "DT_BLK", "DT_REG", "DT_LNK", "DT_SOCK"}
SIGNAL_NAMES = {
    "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGTRAP", "SIGABRT", "SIGBUS", "SIGFPE", "SIGKILL", "SIGUSR1",
    "SIGSEGV", "SIGUSR2", "SIGPIPE", "SIGALRM", "SIGTERM", "SIGSTKFLT", "SIGCHLD", "SIGCONT", "SIGSTOP",
    "SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGURG", "SIGXCPU", "SIGXFSZ", "SIGVTALRM", "SIGPROF", "SIGWINCH",
    "SIGIO", "SIGPWR", "SIGSYS", "SIGRTMIN", "SIGRTMAX",
}
CLOCK_POSIX = {"CLOCK_REALTIME", "CLOCK_MONOTONIC", "CLOCK_PROCESS_CPUTIME_ID", "CLOCK_THREAD_CPUTIME_ID",
               "TIMER_ABSTIME"}
PTHREAD_CREATION = {"PTHREAD_CREATE_JOINABLE": 0, "PTHREAD_CREATE_DETACHED": 1, "PTHREAD_STACK_MIN": 16384}
PTHREAD_MUTEX_TYPES = {"PTHREAD_MUTEX_DEFAULT": 0, "PTHREAD_MUTEX_NORMAL": 0,
                       "PTHREAD_MUTEX_ERRORCHECK": 1, "PTHREAD_MUTEX_RECURSIVE": 2}
PTHREAD_ONCE_CONSTANTS = {"PTHREAD_ONCE_INIT": 0}
PTHREAD_TSD_LIMITS = {"PTHREAD_KEYS_MAX": 128, "PTHREAD_DESTRUCTOR_ITERATIONS": 4}
SPAWN_FLAGS = {"POSIX_SPAWN_RESETIDS", "POSIX_SPAWN_SETPGROUP", "POSIX_SPAWN_SETSIGDEF", "POSIX_SPAWN_SETSIGMASK"}
SIGNAL_MASK_OPERATIONS = {"SIG_BLOCK", "SIG_UNBLOCK", "SIG_SETMASK"}
SIGNAL_ACTION_FLAGS = {"SA_NOCLDSTOP", "SA_NOCLDWAIT", "SA_SIGINFO", "SA_ONSTACK", "SA_RESTART", "SA_NODEFER", "SA_RESETHAND"}
NETDB_CONSTANTS = {
    "AI_PASSIVE": 1, "AI_CANONNAME": 2, "AI_NUMERICHOST": 4, "AI_V4MAPPED": 8,
    "AI_ALL": 16, "AI_ADDRCONFIG": 32, "AI_NUMERICSERV": 1024,
    "EAI_BADFLAGS": -1, "EAI_NONAME": -2, "EAI_AGAIN": -3, "EAI_FAIL": -4,
    "EAI_FAMILY": -6, "EAI_SOCKTYPE": -7, "EAI_SERVICE": -8,
    "EAI_MEMORY": -10, "EAI_SYSTEM": -11, "EAI_OVERFLOW": -12,
    "NI_NUMERICHOST": 1, "NI_NUMERICSERV": 2, "NI_NOFQDN": 4,
    "NI_NAMEREQD": 8, "NI_DGRAM": 16,
}
TERMIOS_POSIX_CONSTANTS = {
    "NCCS": 0x13, "VINTR": 0, "VQUIT": 1, "VERASE": 2, "VKILL": 3, "VEOF": 4, "VTIME": 5,
    "VMIN": 6, "VSTART": 8, "VSTOP": 9, "VSUSP": 10, "VEOL": 11, "IGNBRK": 1, "BRKINT": 2,
    "IGNPAR": 4, "PARMRK": 8, "INPCK": 0x10, "ISTRIP": 0x20, "INLCR": 0x40, "IGNCR": 0x80,
    "ICRNL": 0x100, "IXON": 0x400, "IXANY": 0x800, "IXOFF": 0x1000, "OPOST": 1, "ONLCR": 4,
    "OCRNL": 8, "ONOCR": 0x10, "ONLRET": 0x20, "OFILL": 0x40, "OFDEL": 0x80, "NLDLY": 0x100,
    "NL0": 0, "NL1": 0x100, "CRDLY": 0x600, "CR0": 0, "CR1": 0x200, "CR2": 0x400, "CR3": 0x600,
    "TABDLY": 0x1800, "TAB0": 0, "TAB1": 0x800, "TAB2": 0x1000, "TAB3": 0x1800, "BSDLY": 0x2000,
    "BS0": 0, "BS1": 0x2000, "VTDLY": 0x4000, "VT0": 0, "VT1": 0x4000, "FFDLY": 0x8000, "FF0": 0,
    "FF1": 0x8000, "CSIZE": 0x30, "CS5": 0, "CS6": 0x10, "CS7": 0x20, "CS8": 0x30, "CSTOPB": 0x40,
    "CREAD": 0x80, "PARENB": 0x100, "PARODD": 0x200, "HUPCL": 0x400, "CLOCAL": 0x800, "ISIG": 1,
    "ICANON": 2, "ECHO": 8, "ECHOE": 0x10, "ECHOK": 0x20, "ECHONL": 0x40, "NOFLSH": 0x80,
    "TOSTOP": 0x100, "IEXTEN": 0x8000, "TCSANOW": 0, "TCSADRAIN": 1, "TCSAFLUSH": 2, "B0": 0,
    "B50": 1, "B75": 2, "B110": 3, "B134": 4, "B150": 5, "B200": 6, "B300": 7, "B600": 8,
    "B1200": 9, "B1800": 10, "B2400": 11, "B4800": 12, "B9600": 13, "B19200": 14, "B38400": 15,
    "TCIFLUSH": 0, "TCOFLUSH": 1, "TCIOFLUSH": 2,
    "TCOOFF": 0, "TCOON": 1, "TCIOFF": 2, "TCION": 3,
}
TERMIOS_LINUX_SPEEDS = {
    "B57600": 0x1001, "B115200": 0x1002, "B230400": 0x1003, "B460800": 0x1004, "B500000": 0x1005,
    "B576000": 0x1006, "B921600": 0x1007, "B1000000": 0x1008, "B1152000": 0x1009,
    "B1500000": 0x100a, "B2000000": 0x100b, "B2500000": 0x100c, "B3000000": 0x100d,
    "B3500000": 0x100e, "B4000000": 0x100f,
}
LANGINFO_CONSTANTS = {"CODESET": 14}
MATH_XSI_CONSTANTS = {"M_PI": "3.141592653589793238462643383279502884"}
FNM_CONSTANTS = {"FNM_PATHNAME": 1, "FNM_NOESCAPE": 2, "FNM_PERIOD": 4, "FNM_CASEFOLD": 16,
                 "FNM_IGNORECASE": 16, "FNM_NOMATCH": 1}
GLOB_CONSTANTS = {"GLOB_ERR": 1, "GLOB_MARK": 2, "GLOB_NOSORT": 4,
                  "GLOB_DOOFFS": 8, "GLOB_NOCHECK": 16, "GLOB_APPEND": 32,
                  "GLOB_NOESCAPE": 64, "GLOB_NOSPACE": 1, "GLOB_ABORTED": 2,
                  "GLOB_NOMATCH": 3}
REGEX_CONSTANTS = {"REG_EXTENDED": 1, "REG_ICASE": 2, "REG_NEWLINE": 4,
                   "REG_NOSUB": 8, "REG_NOTBOL": 1, "REG_NOTEOL": 2,
                   "REG_NOMATCH": 1, "REG_BADPAT": 2, "REG_ECOLLATE": 3,
                   "REG_ECTYPE": 4, "REG_EESCAPE": 5, "REG_ESUBREG": 6,
                   "REG_EBRACK": 7, "REG_EPAREN": 8, "REG_EBRACE": 9,
                   "REG_BADBR": 10, "REG_ERANGE": 11, "REG_ESPACE": 12,
                   "REG_BADRPT": 13}
POSIX_SCOPE = {
    "regex.h": {"functions": {"regcomp", "regerror", "regexec", "regfree"},
                "types": {"regex_t", "regmatch_t", "regoff_t"}, "macros": set(REGEX_CONSTANTS)},
    "glob.h": {"functions": {"glob", "globfree"}, "types": {"glob_t"}, "macros": set(GLOB_CONSTANTS)},
    "fnmatch.h": {"functions": {"fnmatch"}, "macros": set(FNM_CONSTANTS)},
    "langinfo.h": {"functions": {"nl_langinfo"}, "types": {"nl_item"}, "macros": set(LANGINFO_CONSTANTS)},
    "math.h": {"macros": set(MATH_XSI_CONSTANTS)},
    "termios.h": {
        "functions": {"cfgetispeed", "cfgetospeed", "cfsetispeed", "cfsetospeed", "tcgetattr", "tcsetattr",
                      "tcdrain", "tcflow", "tcflush", "tcsendbreak", "tcgetsid"},
        "types": {"cc_t", "pid_t", "speed_t", "tcflag_t", "struct termios"},
        "macros": set(TERMIOS_POSIX_CONSTANTS),
    },
    "sched.h": {"functions": {"sched_yield"}},
    "netdb.h": {"functions": {"freeaddrinfo", "gai_strerror", "getaddrinfo", "getnameinfo"},
                "types": {"struct addrinfo"}, "macros": set(NETDB_CONSTANTS)},
    "sys/socket.h": {"functions": {"accept", "bind", "connect", "getpeername", "getsockname", "getsockopt", "listen", "recv", "recvfrom", "recvmsg", "send", "sendmsg", "sendto", "setsockopt", "shutdown", "socket", "socketpair"},
        "types": {"sa_family_t", "socklen_t", "struct cmsghdr", "struct linger", "struct msghdr", "struct sockaddr", "struct sockaddr_storage"},
        "macros": {"AF_INET", "AF_INET6", "AF_UNIX", "AF_UNSPEC", "CMSG_DATA", "CMSG_FIRSTHDR", "CMSG_LEN", "CMSG_NXTHDR", "CMSG_SPACE", "MSG_CTRUNC", "MSG_DONTROUTE", "MSG_EOR", "MSG_NOSIGNAL", "MSG_OOB", "MSG_PEEK", "MSG_TRUNC", "MSG_WAITALL", "PF_INET", "SCM_RIGHTS", "SHUT_RD", "SHUT_RDWR", "SHUT_WR", "SOCK_DGRAM", "SOCK_RAW", "SOCK_SEQPACKET", "SOCK_STREAM", "SOL_SOCKET", "SO_ACCEPTCONN", "SO_BROADCAST", "SO_ERROR", "SO_KEEPALIVE", "SO_LINGER", "SO_RCVBUF", "SO_RCVTIMEO", "SO_REUSEADDR", "SO_SNDBUF", "SO_TYPE"}},
    "sys/un.h": {"types": {"struct sockaddr_un"}},
    "sys/uio.h": {"types": {"struct iovec"}},
    "netinet/in.h": {"types": {"in_addr_t", "in_port_t", "struct in6_addr", "struct in_addr", "struct sockaddr_in", "struct sockaddr_in6"},
        "macros": {"IN6ADDR_ANY_INIT", "IN6ADDR_LOOPBACK_INIT", "INADDR_ANY", "INADDR_BROADCAST", "INADDR_LOOPBACK", "INADDR_NONE", "INET_ADDRSTRLEN", "INET6_ADDRSTRLEN", "IPPROTO_ICMP", "IPPROTO_IP", "IPPROTO_IPV6", "IPPROTO_TCP", "IPPROTO_UDP"}},
    "arpa/inet.h": {"functions": {"htonl", "htons", "inet_addr", "inet_ntoa", "inet_ntop", "inet_pton", "ntohl", "ntohs"}},
    "poll.h": {"functions": {"poll"},
        "types": {"nfds_t", "struct pollfd"},
        "macros": {"POLLERR", "POLLHUP", "POLLIN", "POLLNVAL", "POLLOUT", "POLLPRI", "POLLRDBAND", "POLLRDNORM", "POLLWRBAND", "POLLWRNORM"}},
    "unistd.h": {"functions": {"_Fork", "_exit", "close", "dup", "dup2", "execv", "execve", "execvp", "fork", "getcwd", "getopt",
                               "getpid", "getppid", "isatty", "lseek", "pipe", "pipe2", "read", "readlink",
                               "rmdir", "unlink", "write", "access", "fchown", "fsync", "ftruncate", "geteuid",
                               "pread", "pwrite", "sysconf"},
                 "types": {"size_t", "ssize_t", "off_t", "pid_t", "uid_t", "gid_t"},
                 "macros": set(POSIX_FDS) | SEEK_ORIGINS | ACCESS_MODES | SYSCONF_NAMES,
                 "objects": {"environ", "optarg", "opterr", "optind", "optopt"}},
    "string.h": {"functions": {"strdup", "strerror_r"}},
    "stdlib.h": {"functions": {"mkstemp", "posix_memalign", "putenv", "setenv", "unsetenv"}},
    "fcntl.h": {"functions": {"creat", "fcntl", "open", "openat"},
                "types": {"mode_t", "off_t", "pid_t", "struct flock", "struct f_owner_ex"},
                "macros": OPEN_FLAGS | SEEK_ORIGINS | FCNTL_POSIX},
    "sys/stat.h": {"functions": {"chmod", "fchmod", "fstat", "fstatat", "lstat", "mkdir", "stat", "umask"},
                   "types": {"mode_t", "uid_t", "gid_t", "struct stat"},
                   "macros": MODE_BITS | STAT_MODE_BITS | {"S_IS" + kind for kind in STAT_FILE_KINDS}},
    "sys/mman.h": {"functions": {"mmap", "munmap"}, "types": {"off_t", "size_t"},
                   "macros": MMAP_POSIX | {"MAP_FAILED"}},
    "sys/time.h": {"functions": {"utimes"}, "types": {"time_t", "suseconds_t", "struct timeval"}},
    "sys/types.h": {"types": {"blkcnt_t", "blksize_t", "clock_t", "clockid_t", "dev_t", "gid_t",
                             "ino_t", "mode_t", "nlink_t", "off_t", "pid_t", "size_t",
                             "ssize_t", "suseconds_t", "time_t", "uid_t"}},
    "dirent.h": {"functions": {"closedir", "dirfd", "fdopendir", "opendir", "readdir"},
                 "types": {"DIR", "struct dirent"}},
    "sys/wait.h": {"functions": {"wait", "waitpid"}, "types": {"pid_t"},
                   "macros": {"WNOHANG", "WUNTRACED", "WCONTINUED", "WIFEXITED", "WEXITSTATUS",
                              "WIFSIGNALED", "WTERMSIG", "WIFSTOPPED", "WSTOPSIG", "WIFCONTINUED"}},
    "pthread.h": {"functions": {"pthread_atfork", "pthread_attr_destroy", "pthread_attr_getdetachstate", "pthread_attr_getguardsize",
                               "pthread_attr_getstacksize", "pthread_attr_init", "pthread_attr_setdetachstate",
                               "pthread_attr_setguardsize", "pthread_attr_setstacksize", "pthread_create",
                               "pthread_detach", "pthread_equal", "pthread_exit", "pthread_join", "pthread_self",
                               "pthread_mutexattr_init", "pthread_mutexattr_destroy", "pthread_mutexattr_gettype",
                               "pthread_mutexattr_settype", "pthread_mutex_init", "pthread_mutex_destroy",
                               "pthread_mutex_lock", "pthread_mutex_trylock", "pthread_mutex_unlock",
                               "pthread_mutex_timedlock", "pthread_mutex_clocklock",
                               "pthread_cond_init", "pthread_cond_destroy", "pthread_cond_wait",
                               "pthread_cond_timedwait", "pthread_cond_clockwait", "pthread_cond_signal",
                               "pthread_cond_broadcast", "pthread_condattr_init", "pthread_condattr_destroy",
                               "pthread_condattr_getclock", "pthread_condattr_setclock",
                               "pthread_key_create", "pthread_key_delete", "pthread_getspecific", "pthread_setspecific",
                               "pthread_once"},
                  "types": {"pthread_attr_t", "pthread_cond_t", "pthread_condattr_t", "pthread_key_t",
                            "pthread_mutex_t", "pthread_mutexattr_t", "pthread_once_t", "pthread_t"},
                  "macros": set(PTHREAD_CREATION) | set(PTHREAD_MUTEX_TYPES) | set(PTHREAD_ONCE_CONSTANTS)
                            | {"PTHREAD_COND_INITIALIZER", "PTHREAD_MUTEX_INITIALIZER"}},
    "limits.h": {"macros": set(PTHREAD_TSD_LIMITS)},
    "spawn.h": {"functions": {"posix_spawn", "posix_spawnp", "posix_spawn_file_actions_init", "posix_spawn_file_actions_destroy",
                             "posix_spawn_file_actions_addclose", "posix_spawn_file_actions_adddup2",
                             "posix_spawn_file_actions_addopen", "posix_spawnattr_init", "posix_spawnattr_destroy",
                             "posix_spawnattr_getflags", "posix_spawnattr_setflags", "posix_spawnattr_getpgroup",
                             "posix_spawnattr_setpgroup", "posix_spawnattr_getsigmask", "posix_spawnattr_setsigmask",
                             "posix_spawnattr_getsigdefault", "posix_spawnattr_setsigdefault"},
                "types": {"posix_spawnattr_t", "posix_spawn_file_actions_t"}, "macros": SPAWN_FLAGS},
    "setjmp.h": {"functions": {"sigsetjmp", "siglongjmp"}, "types": {"sigjmp_buf"}},
    "time.h": {"functions": {"clock_gettime", "clock_getres", "clock_nanosleep", "gmtime_r", "localtime_r", "nanosleep"},
               "types": {"clockid_t"}, "macros": CLOCK_POSIX},
    "signal.h": {"functions": {"kill", "sigaction", "sigaddset", "sigdelset", "sigemptyset", "sigfillset",
                               "sigismember", "sigpending", "sigprocmask", "sigsuspend"},
                 "types": {"pid_t", "siginfo_t", "sigset_t", "struct sigaction"},
                 "macros": SIGNAL_MASK_OPERATIONS | SIGNAL_ACTION_FLAGS | {"SIGRTMIN", "SIGRTMAX"}},
    "libgen.h": {"functions": {"dirname"}},
    "stdio.h": {"functions": {"fileno", "flockfile", "fseeko", "ftello", "funlockfile", "getc_unlocked", "pclose", "popen", "putchar_unlocked"}},
}
EXTENSION_SCOPE = {
    "termios.h": {"macros": set(TERMIOS_LINUX_SPEEDS)},
    "setjmp.h": {"functions": {"_longjmp", "_setjmp"}},
    "stdio.h": {"functions": {"ferror_unlocked", "fputs_unlocked", "vasprintf"}},
    "sys/ioctl.h": {"functions": {"ioctl"}},
    "sys/socket.h": {"functions": {"accept4"},
        "macros": {"AF_LOCAL", "CMSG_ALIGN", "MSG_CMSG_CLOEXEC", "MSG_DONTWAIT", "SCM_CREDENTIALS", "SOCK_CLOEXEC", "SOCK_NONBLOCK", "SO_PASSCRED", "SO_PEERCRED", "SO_REUSEPORT"},
        "types": {"struct ucred"}},
    "poll.h": {"functions": {"ppoll"},
        "macros": {"POLLRDHUP"}},
    "sys/epoll.h": {"functions": {"epoll_create", "epoll_create1", "epoll_ctl", "epoll_pwait", "epoll_wait"},
        "types": {"epoll_data_t", "struct epoll_event"},
        "macros": {"EPOLLERR", "EPOLLET", "EPOLLEXCLUSIVE", "EPOLLHUP", "EPOLLIN", "EPOLLONESHOT", "EPOLLOUT", "EPOLLPRI", "EPOLLRDBAND", "EPOLLRDHUP", "EPOLLRDNORM", "EPOLLWAKEUP", "EPOLLWRBAND", "EPOLLWRNORM", "EPOLL_CLOEXEC", "EPOLL_CTL_ADD", "EPOLL_CTL_DEL", "EPOLL_CTL_MOD"}},
    "sys/mman.h": {"functions": {"mremap"}},
    "sys/time.h": {"functions": {"gettimeofday"}},
}
COMPILER_ATOMIC_ABI = {
    "__atomic_load", "__atomic_store", "__atomic_exchange", "__atomic_compare_exchange", "__atomic_is_lock_free",
    "__atomic_load_16", "__atomic_store_16", "__atomic_exchange_16", "__atomic_compare_exchange_16",
    "__atomic_fetch_add_16", "__atomic_fetch_sub_16", "__atomic_fetch_and_16",
    "__atomic_fetch_or_16", "__atomic_fetch_xor_16", "__atomic_fetch_nand_16",
}
RUNTIME_ABI = {
    "assert.h": {"__al_assert_fail"},
    "compiler_rt.h": COMPILER_ATOMIC_ABI | {"__stack_chk_fail"},
    "errno.h": {"__errno_location"},
}
MACRO_BACKED_ABI = {("setjmp.h", "setjmp")}


class SpecError(ValueError):
    pass


@dataclass(frozen=True)
class Abi:
    narrow_args: tuple[str, ...]
    variadic: bool
    noreturn: bool = False


@dataclass(frozen=True)
class Provenance:
    origin: str
    url: str
    revision: str
    upstream_path: str
    license: str
    notice: str


@dataclass(frozen=True)
class FunctionSpec:
    name: str
    header: str
    prototype: str
    standard: tuple[str, ...]
    deps: tuple[str, ...]
    errno: tuple[str, ...]
    mt_safe: bool
    as_safe: bool
    oracles: tuple[str, ...]
    provenance: str | Provenance
    semantics: tuple[str, ...]
    abi: Abi
    path: Path


@dataclass(frozen=True)
class InventoryItem:
    header: str
    kind: str
    name: str
    standard: str
    availability: str


@dataclass(frozen=True)
class Project:
    root: Path
    functions: dict[str, FunctionSpec]
    inventory: tuple[InventoryItem, ...]
    deviations: tuple[dict[str, str], ...]


def fail(where, message):
    raise SpecError(f"{where}: {message}")


def read_toml(path):
    if path.is_symlink():
        fail(path, "TOML input must be a regular file")
    try:
        with path.open("rb") as source:
            return tomllib.load(source)
    except (OSError, ValueError) as error:
        fail(path, str(error))


def keys(obj, required, where, optional=()):
    if type(obj) is not dict:
        fail(where, "expected a TOML table")
    if extra := obj.keys() - set(required) - set(optional):
        fail(where, f"unknown field(s): {', '.join(sorted(extra))}")
    if missing := set(required) - obj.keys():
        fail(where, f"missing field(s): {', '.join(sorted(missing))}")


def matching(value, pattern, where):
    if type(value) is not str or re.fullmatch(pattern, value) is None:
        fail(where, f"invalid value: {value!r}")
    return value


def string_list(value, pattern, where, *, nonempty=False):
    if type(value) is not list or (nonempty and not value):
        fail(where, "expected a nonempty array of strings" if nonempty else "expected an array of strings")
    items = tuple(matching(item, pattern, where) for item in value)
    if len(set(items)) != len(items):
        fail(where, "duplicate value")
    return items


def boolean(value, where):
    if type(value) is not bool:
        fail(where, "expected a boolean")
    return value


def version_one(value, where):
    if type(value) is not int or value != 1:
        fail(where, "unsupported schema version; expected integer 1")


def load_network_abi(root):
    path = regular_file(root, "spec/types/linux-x86_64-net.toml", "network ABI")
    document = read_toml(path)
    keys(document, {"schema_version", "types", "syscalls", "socket", "poll", "epoll", "inet", "layout"}, path)
    version_one(document["schema_version"], path)
    expected_types = {"socklen_t": "unsigned int", "sa_family_t": "unsigned short",
                      "nfds_t": "unsigned long", "in_port_t": "uint16_t", "in_addr_t": "uint32_t"}
    if document["types"] != expected_types:
        fail(path, "network ABI types must match the selected Linux LP64 types")
    groups = {
        "syscalls": {"accept", "accept4", "bind", "connect", "epoll_create", "epoll_create1", "epoll_ctl", "epoll_pwait", "epoll_wait", "getpeername", "getsockname", "getsockopt", "listen", "poll", "ppoll", "recvfrom", "recvmsg", "sendmsg", "sendto", "setsockopt", "shutdown", "socket", "socketpair"},
        "socket": {"AF_INET", "AF_INET6", "AF_LOCAL", "AF_UNIX", "AF_UNSPEC", "MSG_CMSG_CLOEXEC", "MSG_CTRUNC", "MSG_DONTROUTE", "MSG_DONTWAIT", "MSG_EOR", "MSG_NOSIGNAL", "MSG_OOB", "MSG_PEEK", "MSG_TRUNC", "MSG_WAITALL", "PF_INET", "SCM_CREDENTIALS", "SCM_RIGHTS", "SHUT_RD", "SHUT_RDWR", "SHUT_WR", "SOCK_CLOEXEC", "SOCK_DGRAM", "SOCK_NONBLOCK", "SOCK_RAW", "SOCK_SEQPACKET", "SOCK_STREAM", "SOL_SOCKET", "SO_ACCEPTCONN", "SO_BROADCAST", "SO_ERROR", "SO_KEEPALIVE", "SO_LINGER", "SO_PASSCRED", "SO_PEERCRED", "SO_RCVBUF", "SO_RCVTIMEO", "SO_REUSEADDR", "SO_REUSEPORT", "SO_SNDBUF", "SO_TYPE"},
        "poll": {"POLLERR", "POLLHUP", "POLLIN", "POLLNVAL", "POLLOUT", "POLLPRI", "POLLRDBAND", "POLLRDHUP", "POLLRDNORM", "POLLWRBAND", "POLLWRNORM"},
        "epoll": {"EPOLLERR", "EPOLLET", "EPOLLEXCLUSIVE", "EPOLLHUP", "EPOLLIN", "EPOLLONESHOT", "EPOLLOUT", "EPOLLPRI", "EPOLLRDBAND", "EPOLLRDHUP", "EPOLLRDNORM", "EPOLLWAKEUP", "EPOLLWRBAND", "EPOLLWRNORM", "EPOLL_CLOEXEC", "EPOLL_CTL_ADD", "EPOLL_CTL_DEL", "EPOLL_CTL_MOD"},
        "inet": {"INADDR_ANY", "INADDR_BROADCAST", "INADDR_LOOPBACK", "INADDR_NONE", "INET_ADDRSTRLEN", "INET6_ADDRSTRLEN", "IPPROTO_ICMP", "IPPROTO_IP", "IPPROTO_IPV6", "IPPROTO_TCP", "IPPROTO_UDP"},
        "layout": {"cmsghdr_size", "epoll_event_data", "epoll_event_size", "iovec_size", "kernel_sigset_size", "msghdr_size", "pollfd_size", "sockaddr_in6_size", "sockaddr_in_size", "sockaddr_size", "sockaddr_storage_align", "sockaddr_storage_size", "sockaddr_un_path"},
    }
    for name, expected in groups.items():
        constants = document[name]
        keys(constants, expected, f"{path}: {name}")
        if any(type(value) is not int or not 0 <= value <= 0xffffffff for value in constants.values()):
            fail(path, f"{name} values must be unsigned 32-bit integer constants")
    return document


def load_file_abi(root):
    path = regular_file(root, "spec/types/linux-x86_64-files.toml", "file ABI")
    document = read_toml(path)
    keys(document, {"schema_version", "types", "syscalls", "seek", "open_flags", "mode_bits",
                    "dirent_types", "descriptor_flags", "access_modes", "sysconf_names", "mapping"}, path)
    version_one(document["schema_version"], path)
    if document["types"] != FILE_TYPES:
        fail(path, "file ABI types must match the selected Linux LP64 types")
    groups = {
        "syscalls": {"fstat", "lseek", "ioctl", "pipe", "dup", "dup2", "fcntl", "getcwd", "rename", "mkdir", "rmdir",
                     "unlink", "readlink", "chmod", "umask", "getdents64", "openat", "newfstatat", "getrandom",
                     "mmap", "munmap", "pread64", "pwrite64", "mremap", "fsync", "ftruncate",
                     "fchmod", "fchown", "fstatfs", "pwritev2"},
        "seek": SEEK_ORIGINS | {"SEEK_DATA", "SEEK_HOLE"},
        "open_flags": OPEN_FLAGS | {"AT_EMPTY_PATH", "O_PATH", "O_TMPFILE"},
        "mode_bits": MODE_BITS | STAT_MODE_BITS,
        "dirent_types": DIRENT_TYPES,
        "descriptor_flags": FCNTL_POSIX | FCNTL_LINUX,
        "access_modes": ACCESS_MODES,
        "sysconf_names": SYSCONF_NAMES,
        "mapping": MMAP_POSIX | MMAP_LINUX,
    }
    for name, expected in groups.items():
        constants = document[name]
        keys(constants, expected, f"{path}: {name}")
        if any(type(value) is not int or not -(1 << 31) <= value < (1 << 31)
               for value in constants.values()):
            fail(path, f"{name} values must be signed 32-bit integer constants")
    return document


def load_process_abi(root):
    path = regular_file(root, "spec/types/linux-x86_64-process.toml", "process ABI")
    document = read_toml(path)
    keys(document, {"schema_version", "types", "syscalls", "wait_flags", "spawn_flags"}, path)
    version_one(document["schema_version"], path)
    if document["types"] != {"pid_t": "int"}:
        fail(path, "process IDs must use the selected signed 32-bit type")
    keys(document["syscalls"], {"access", "getpid", "fork", "execve", "wait4", "getrlimit", "getuid", "getgid", "geteuid",
                                "setpgid", "getppid", "setresuid", "setresgid", "pipe2"}, path)
    keys(document["wait_flags"], {"WNOHANG", "WUNTRACED", "WCONTINUED"}, path)
    keys(document["spawn_flags"], SPAWN_FLAGS, path)
    if any(type(value) is not int or not 0 <= value < 1 << 31
           for group in ("syscalls", "wait_flags", "spawn_flags") for value in document[group].values()):
        fail(path, "process ABI constants must be nonnegative signed 32-bit integers")
    return document


def load_signal_abi(root):
    path = regular_file(root, "spec/types/linux-x86_64-signal.toml", "signal ABI")
    document = read_toml(path)
    groups = {"syscalls": {"rt_sigaction", "rt_sigprocmask", "kill", "rt_sigpending", "rt_sigsuspend", "gettid", "tgkill"},
              "signals": SIGNAL_NAMES, "mask_operations": SIGNAL_MASK_OPERATIONS, "action_flags": SIGNAL_ACTION_FLAGS,
              "info_codes": {"SI_USER", "SI_KERNEL", "SI_QUEUE", "SI_TKILL"}}
    keys(document, {"schema_version", *groups}, path)
    version_one(document["schema_version"], path)
    for group, names in groups.items():
        keys(document[group], names, path)
        if any(type(value) is not int or not -(1 << 31) <= value < 1 << 32 for value in document[group].values()):
            fail(path, f"{group} values must fit in 32 bits")
    return document


def load_time_abi(root):
    path = regular_file(root, "spec/types/linux-x86_64-time.toml", "time64 ABI")
    document = read_toml(path)
    keys(document, {"schema_version", "types", "syscalls", "constants"}, path)
    version_one(document["schema_version"], path)
    if document["types"] != {"time_t": "long", "clock_t": "long", "clockid_t": "int", "suseconds_t": "long"}:
        fail(path, "time ABI types must match Linux x86-64 time64")
    keys(document["syscalls"], {"nanosleep", "gettimeofday", "utimes", "clock_gettime", "clock_getres", "clock_nanosleep"}, path)
    keys(document["constants"], CLOCK_POSIX | {"CLOCKS_PER_SEC", "TIME_UTC", "CLOCK_MONOTONIC_RAW",
         "CLOCK_REALTIME_COARSE", "CLOCK_MONOTONIC_COARSE", "CLOCK_BOOTTIME", "CLOCK_REALTIME_ALARM",
         "CLOCK_BOOTTIME_ALARM", "CLOCK_TAI"}, path)
    if any(type(value) is not int or not 0 <= value < 1 << 31
           for group in ("syscalls", "constants") for value in document[group].values()):
        fail(path, "time ABI constants must be nonnegative signed 32-bit integers")
    return document


def relative_path(value, where):
    matching(value, r"[A-Za-z0-9_.+/-]+", where)
    path = PurePosixPath(value)
    if path.is_absolute() or path.as_posix() != value or any(part in (".", "..") for part in value.split("/")):
        fail(where, "expected a normalized repository-relative path")
    return path


def regular_file(root, relative, where):
    path = root / relative
    if not path.is_relative_to(root) or ".." in path.relative_to(root).parts:
        fail(where, f"expected a repository-contained path without parent components: {relative}")
    current = path
    while current != root:
        if current.is_symlink():
            fail(where, f"symbolic links are unsupported: {relative}")
        current = current.parent
    if not path.is_file():
        fail(where, f"missing regular file: {relative}")
    return path


def sha256_file(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def snapshot_inputs(root, paths):
    root = Path(root).resolve()
    result = {}
    for value in paths:
        relative = str(value)
        path = relative_path(relative, "evidence inputs")
        if relative in result:
            fail("evidence inputs", f"duplicate path: {relative}")
        result[relative] = sha256_file(regular_file(root, path, "evidence inputs"))
    return dict(sorted(result.items()))


def inventory_group(table, header, standard, availability, where):
    for kind in KINDS:
        patterns = {
            "types": rf"(?:(?:struct|enum|union) )?{IDENTIFIER}",
            "pragmas": r"STDC [A-Z][A-Z0-9_]+",
            "families": r"[A-Za-z_][A-Za-z0-9_]*\{N\}[A-Za-z0-9_]*",
        }
        for name in string_list(table.get(kind, []), patterns.get(kind, IDENTIFIER), f"{where}.{kind}"):
            yield InventoryItem(header, kind, name, standard, availability)


def load_inventory(root):
    path = regular_file(root, "spec/inventory.toml", "inventory")
    doc = read_toml(path)
    keys(doc, {"schema_version", "sources", "headers"}, path)
    version_one(doc["schema_version"], path)
    keys(doc["sources"], {"c17", "posix"}, f"{path}: sources")
    if doc["sources"] != {"c17": C17_SOURCE, "posix": POSIX_SOURCE}:
        fail(path, "inventory sources must match the documented standards references")
    tables = doc["headers"]
    if type(tables) is not list or not tables:
        fail(path, "expected a nonempty [[headers]] array")
    headers, identities, items = set(), set(), []
    for index, table in enumerate(tables, 1):
        where = f"{path}: headers[{index}]"
        keys(table, {"name", "standard", "count"}, where, (*KINDS, "conditional"))
        name = matching(table["name"], HEADER, f"{where}.name")
        standard = matching(table["standard"], STANDARD, f"{where}.standard")
        edition = standard.split()[0]
        if (edition, name) in headers:
            fail(where, f"duplicate header: {edition} {name}")
        headers.add((edition, name))
        if edition == "C17":
            if name[:-2] not in C17_HEADERS or standard != f"C17 7.{C17_HEADERS[name[:-2]]}":
                fail(where, "incorrect C17 header or clause")
        elif edition == "Runtime":
            if name not in RUNTIME_ABI or standard != f"Runtime ABI <{name}>":
                fail(where, "outside the named runtime ABI scope")
        elif edition == "Extension":
            if name not in EXTENSION_SCOPE or standard != f"Extension ABI <{name}>":
                fail(where, "outside the named Linux compatibility extension scope")
        elif name not in POSIX_SCOPE or standard != f"POSIX.1-2024 XBD <{name}>":
            fail(where, "outside the named POSIX scope")
        found = list(inventory_group(table, name, standard, "required", where))
        groups = table.get("conditional", [])
        if type(groups) is not list:
            fail(where, "expected a conditional array of tables")
        if edition != "C17" and groups:
            fail(where, "the POSIX and runtime ABI bootstrap subsets have no conditional entries")
        if edition == "Runtime" and {(i.kind, i.name) for i in found} != {
                ("functions", entry) for entry in RUNTIME_ABI[name]}:
            fail(where, "expected only the named runtime ABI entries")
        if edition == "Extension" and {(i.kind, i.name) for i in found} != {
                (kind, item) for kind, entries in EXTENSION_SCOPE[name].items() for item in entries}:
            fail(where, "expected only the named Linux compatibility extension entries")
        if edition == "POSIX.1-2024" and {(i.kind, i.name) for i in found} != {
                (kind, item) for kind, entries in POSIX_SCOPE[name].items() for item in entries}:
            fail(where, "expected the explicitly scoped POSIX entries")
        conditions = set()
        for group in groups:
            keys(group, {"when"}, where, KINDS)
            when = matching(group["when"], r"[ -~]+", f"{where}.conditional.when")
            if when in conditions or when == "required":
                fail(where, f"duplicate or reserved availability: {when}")
            conditions.add(when)
            conditional = list(inventory_group(group, name, standard, when, where))
            if not conditional:
                fail(where, f"empty conditional group: {when}")
            found.extend(conditional)
        count = table["count"]
        if type(count) is not int or count < 1 or count != len(found):
            fail(where, f"count {count!r} does not match {len(found)} entries")
        for item in found:
            identity = (edition, name, item.name)
            if identity in identities:
                fail(where, f"duplicate identifier: {item.name}")
            identities.add(identity)
            items.append(item)
    expected = {("C17", name + ".h") for name in C17_HEADERS} | {("POSIX.1-2024", name) for name in POSIX_SCOPE}
    expected |= {("Runtime", name) for name in RUNTIME_ABI}
    expected |= {("Extension", name) for name in EXTENSION_SCOPE}
    if missing := expected - headers:
        fail(path, "missing required header(s): " + ", ".join(" ".join(pair) for pair in sorted(missing)))
    return tuple(sorted(items, key=lambda item: (item.standard, item.header, item.kind, item.name)))


def split_parameters(prototype, name, where):
    # Deliberately accepts a portable, single-declaration subset, not arbitrary C.
    match = re.fullmatch(
        rf"(?P<return>[A-Za-z_][A-Za-z0-9_ *]*?)(?<![A-Za-z0-9_]){re.escape(name)} *\((?P<params>[A-Za-z0-9_ *,().\[\]]+)\)",
        prototype,
    ) if type(prototype) is str else None
    if not match:
        fail(where, "expected one C function prototype matching name, without a semicolon")
    ret = match["return"].strip()
    if not re.fullmatch(rf"{IDENTIFIER}(?: +{IDENTIFIER}| *\*)*", ret):
        fail(where, "unsupported return declarator")
    if ret.split()[0] in ("static", "inline", "typedef", "register", "auto"):
        fail(where, "public prototypes must declare external functions")
    params = []
    stack = []
    start = 0
    for index, char in enumerate(match["params"]):
        if char in "([":
            stack.append(")" if char == "(" else "]")
        elif char in ")]":
            if not stack or char != stack.pop():
                fail(where, "unbalanced parameter declarator")
        elif char == "," and not stack:
            params.append(match["params"][start:index].strip())
            start = index + 1
    if stack:
        fail(where, "unbalanced parameter declarator")
    params.append(match["params"][start:].strip())
    if params == ["void"]:
        return ret, []
    for index, param in enumerate(params):
        if param == "...":
            if index == 0 or index != len(params) - 1:
                fail(where, "ellipsis must follow a named parameter at the end")
        elif (not re.match(IDENTIFIER, param) or param == "void"
              or "." in param.replace("...", "")):
            fail(where, "invalid parameter declarator")
    return ret, params


ABI_REGISTERS = (
    ("edi", "di", "dil"), ("esi", "si", "sil"), ("edx", "dx", "dl"),
    ("ecx", "cx", "cl"), ("r8d", "r8w", "r8b"), ("r9d", "r9w", "r9b"),
)
ABI_POSITION = {reg: index for index, group in enumerate(ABI_REGISTERS) for reg in group}


def builtin_abi_class(declaration):
    """Classify common builtin declarators; opaque types require explicit metadata."""
    if "*" in declaration or "[" in declaration:
        return "wide", ()
    if "(" in declaration:
        return None, ()
    # The name of a parameter, if present, follows the builtin type specifiers.
    qualifiers = {"const", "volatile", "restrict", "_Atomic", "register", "_Noreturn", "extern"}
    type_words = {"signed", "unsigned", "short", "int", "long", "char", "_Bool", "void",
                  "float", "double", "_Complex", "__int128"}
    words = [word for word in declaration.split() if word not in qualifiers]
    if len(words) > 1 and words[-1] not in type_words:
        words.pop()
    if words in (["size_t"], ["off_t"], ["time_t"], ["clock_t"], ["__al_sighandler_t"], ["jmp_buf"], ["sigjmp_buf"], ["wctype_t"], ["wctrans_t"], ["nfds_t"], ["ssize_t"]):
        return "wide", ()
    if words in (["mode_t"], ["wint_t"], ["char32_t"], ["socklen_t"], ["in_addr_t"], ["uint32_t"]):
        return "narrow", ("u32",)
    if words in (["char16_t"], ["sa_family_t"], ["in_port_t"], ["uint16_t"]):
        return "narrow", ("u16",)
    if words in (["pid_t"], ["clockid_t"], ["wchar_t"], ["nl_item"]):
        return "narrow", ("s32",)
    counts = {word: words.count(word) for word in set(words)}
    if not words or counts.keys() - type_words:
        return None, ()
    if sorted(words) in [sorted(group.split()) for group in (
        "void", "float", "double", "long double", "float _Complex", "double _Complex",
        "long double _Complex",
    )]:
        return "noninteger", ()
    if words in (["__int128"], ["unsigned", "__int128"], ["signed", "__int128"]):
        return "doublewide", ()
    if words == ["_Bool"]:
        return "narrow", ("u8",)
    if counts.keys() <= {"char", "signed", "unsigned"} and counts.get("char") == 1 and len(words) <= 2:
        return "narrow", (("s8",) if "signed" in words else ("u8",) if "unsigned" in words else ("s8", "u8"))
    if (counts.keys() <= {"signed", "unsigned", "short", "int", "long"}
            and sum(counts.get(word, 0) for word in ("signed", "unsigned")) <= 1
            and counts.get("int", 0) <= 1
            and counts.get("short", 0) + counts.get("long", 0) <= 2
            and not ("short" in counts and ("long" in counts or counts["short"] > 1))):
        if "long" in words:
            return "wide", ()
        return "narrow", (("u" if "unsigned" in words else "s") + ("16" if "short" in words else "32"),)
    return None, ()


def validate_narrow_args(ret, params, narrow, where):
    if builtin_abi_class(ret)[0] is None:
        # An opaque return type may require a hidden pointer in the first
        # integer register. The prototype alone does not resolve that case.
        return
    actual = {ABI_POSITION[item.split(":")[0]]: item for item in narrow}
    position = 0
    for declaration in params:
        if position == len(ABI_REGISTERS) or declaration == "...":
            break
        kind, extensions = builtin_abi_class(declaration)
        if kind is None:
            return
        if kind == "noninteger":
            continue
        if kind == "doublewide":
            # SysV passes both halves in registers or spills the whole argument.
            if position + 2 <= len(ABI_REGISTERS):
                if position in actual or position + 1 in actual:
                    fail(where, f"abi.narrow_args marks a full-width argument as narrow: {declaration!r}")
                position += 2
            continue
        if kind == "narrow":
            expected = {f"{ABI_REGISTERS[position][{'32': 0, '16': 1, '8': 2}[ext[1:]]]}:{ext}"
                        for ext in extensions}
            if actual.get(position) not in expected:
                fail(where, "abi.narrow_args must include " + " or ".join(sorted(expected)) + f" for {declaration!r}")
        elif position in actual:
            fail(where, f"abi.narrow_args marks a full-width argument as narrow: {declaration!r}")
        position += 1
    if any(index >= position for index in actual):
        fail(where, "abi.narrow_args names a register without an incoming fixed argument")


def load_provenance(value, root, name, where):
    if value == "original":
        return value
    fields = ("origin", "url", "revision", "upstream_path", "license", "notice")
    keys(value, fields, where)
    if type(value["origin"]) is not str or value["origin"] not in UPSTREAMS:
        fail(where, "origin is not on the algorithm source allowlist")
    if type(value["license"]) is not str or value["license"] not in LICENSES:
        fail(where, "expected a supported permissive per-file license identifier")
    if value["url"] != UPSTREAMS[value["origin"]]:
        fail(where, f"URL must identify the allowed {value['origin']} upstream")
    revision_pattern = r"[0-9a-f]{64}" if value["origin"] == "fdlibm" else r"[0-9a-f]{40}|[0-9a-f]{64}"
    matching(value["revision"], revision_pattern, f"{where}.revision")
    relative_path(value["upstream_path"], f"{where}.upstream_path")
    if value["notice"] != f"spec/provenance/{name}.txt":
        fail(where, "expected this function's notice under spec/provenance/")
    notice = regular_file(root, relative_path(value["notice"], where), where)
    try:
        if not notice.read_text(encoding="utf-8").strip():
            fail(where, "license notice is empty")
    except (OSError, UnicodeError) as error:
        fail(where, str(error))
    return Provenance(*(value[field] for field in fields))


def load_function(path, root):
    raw = read_toml(path)
    fields = ("name", "header", "prototype", "standard", "deps", "errno",
              "mt_safe", "as_safe", "oracles", "provenance", "semantics", "abi")
    keys(raw, fields, path)
    name = matching(raw["name"], IDENTIFIER, f"{path}: name")
    header = matching(raw["header"], HEADER, f"{path}: header")
    ret, params = split_parameters(raw["prototype"], name, f"{path}: prototype")
    keys(raw["abi"], {"narrow_args", "variadic"}, f"{path}: abi", ("noreturn",))
    narrow = string_list(
        raw["abi"]["narrow_args"],
        r"(?:(?:edi|esi|edx|ecx|r8d|r9d):[su]32|(?:di|si|dx|cx|r8w|r9w):[su]16|(?:dil|sil|dl|cl|r8b|r9b):[su]8)",
        f"{path}: abi.narrow_args",
    )
    positions = [ABI_POSITION[item.split(":")[0]] for item in narrow]
    if len(set(positions)) != len(positions):
        fail(path, "multiple widths specified for the same incoming ABI register")
    variadic = boolean(raw["abi"]["variadic"], f"{path}: abi.variadic")
    if variadic != ("..." in params):
        fail(path, "abi.variadic disagrees with the prototype")
    noreturn = boolean(raw["abi"].get("noreturn", False), f"{path}: abi.noreturn")
    if noreturn != ("_Noreturn" in ret.split()):
        fail(path, "abi.noreturn disagrees with the prototype")
    validate_narrow_args(ret, params, narrow, path)
    return FunctionSpec(
        name, header, raw["prototype"],
        string_list(raw["standard"], STANDARD, f"{path}: standard", nonempty=True),
        string_list(raw["deps"], IDENTIFIER, f"{path}: deps"),
        string_list(raw["errno"], r"E[A-Z0-9]+", f"{path}: errno"),
        boolean(raw["mt_safe"], f"{path}: mt_safe"),
        boolean(raw["as_safe"], f"{path}: as_safe"),
        string_list(raw["oracles"], r"(?:diff|suite|reference|vectors):[A-Za-z0-9][A-Za-z0-9_.+/-]*",
                    f"{path}: oracles", nonempty=True),
        load_provenance(raw["provenance"], root, name, f"{path}: provenance"),
        string_list(raw["semantics"], r"[ -~]+", f"{path}: semantics", nonempty=True),
        Abi(narrow, variadic, noreturn), path.relative_to(root),
    )


def load_deviations(root, functions):
    path = regular_file(root, "spec/deviations.toml", "deviations")
    raw = read_toml(path)
    keys(raw, {"schema_version", "deviations"}, path)
    version_one(raw["schema_version"], path)
    if type(raw["deviations"]) is not list:
        fail(path, "expected an array of deviations")
    seen = set()
    for item in raw["deviations"]:
        keys(item, {"function", "standard", "choice", "reason"}, path)
        function = matching(item["function"], IDENTIFIER, path)
        standard = matching(item["standard"], STANDARD, path)
        for key in ("choice", "reason"):
            matching(item[key], r"[ -~]+", f"{path}: {key}")
        if function not in functions:
            fail(path, f"unknown function: {function}")
        if (function, standard, item["choice"]) in seen:
            fail(path, f"duplicate deviation for {function}")
        seen.add((function, standard, item["choice"]))
    return tuple(raw["deviations"])


def has_runtime_entry(item):
    return item.kind == "functions" or (item.kind == "macros" and item.standard.startswith("C17 ")
                                        and (item.header, item.name) in MACRO_BACKED_ABI)


def load_project(root=ROOT):
    root = Path(root).resolve()
    inventory = load_inventory(root)
    listed = {(item.header, item.name): item for item in inventory if has_runtime_entry(item)}
    functions = {}
    for path in sorted((root / "spec/functions").rglob("*.toml")):
        regular_file(root, path.relative_to(root), path)
        spec = load_function(path, root)
        if spec.name in functions:
            fail(path, f"duplicate function name: {spec.name}")
        if spec.path != Path(f"spec/functions/{spec.header[:-2]}/{spec.name}.toml"):
            fail(path, f"expected spec/functions/{spec.header[:-2]}/{spec.name}.toml")
        if (spec.header, spec.name) not in listed:
            fail(path, f"{spec.name} is not a function in the inventory under {spec.header}")
        group = listed[spec.header, spec.name].standard
        if group.startswith("C17 ") and not any(s == group or s.startswith(group + ".") for s in spec.standard):
            fail(path, f"standard references do not include a clause under {group}")
        if group.startswith("POSIX.1-2024 ") and not ({group, f"POSIX.1-2024 XSH {spec.name}"} & set(spec.standard)):
            fail(path, f"expected a POSIX.1-2024 reference for {spec.name}")
        if group.startswith("Runtime ABI ") and f"Runtime ABI {spec.name}" not in spec.standard:
            fail(path, f"expected a runtime ABI reference for {spec.name}")
        if group.startswith("Extension ABI ") and f"Extension ABI {spec.name}" not in spec.standard:
            fail(path, f"expected a compatibility extension reference for {spec.name}")
        functions[spec.name] = spec
    inventory_names = {item.name for item in listed.values()}
    visited, active = set(), []

    def visit(name):
        if name in active:
            fail("dependencies", "cycle: " + " -> ".join((*active[active.index(name):], name)))
        if name in visited or name not in functions:
            return
        active.append(name)
        for dep in functions[name].deps:
            if dep not in inventory_names:
                fail(functions[name].path, f"dependency not in inventory: {dep}")
            visit(dep)
        active.pop()
        visited.add(name)

    for name in sorted(functions):
        visit(name)
    return Project(root, dict(sorted(functions.items())), inventory, load_deviations(root, functions))


def nasm_name(name):
    # NASM strips the identifier escape for reserved words in ELF.
    return "$" + name if name in {"abs", "div", "wait"} else name


def comment_header(spec):
    provenance = spec.provenance
    fields = [
        ("function", spec.name), ("header", spec.header), ("prototype", spec.prototype),
        ("standard", ", ".join(spec.standard)), ("deps", ", ".join(spec.deps) or "-"),
        ("errno", ", ".join(spec.errno) or "-"), ("mt_safe", str(spec.mt_safe).lower()),
        ("as_safe", str(spec.as_safe).lower()), ("oracles", ", ".join(spec.oracles)),
        ("provenance", provenance if isinstance(provenance, str) else provenance.origin),
        ("narrow_args", ", ".join(spec.abi.narrow_args) or "-"),
        ("variadic", str(spec.abi.variadic).lower()),
    ]
    if spec.abi.noreturn:
        fields.append(("noreturn", "true"))
    if isinstance(provenance, Provenance):
        fields.extend((key, getattr(provenance, key)) for key in ("url", "revision", "upstream_path", "license", "notice"))
    fields.extend(("semantics", line) for line in spec.semantics)
    return ("; BEGIN OPEN ASSEMBLY GENERATED SPEC\n"
            + "".join(f"; {key}: {value}\n" for key, value in fields)
            + "; END OPEN ASSEMBLY GENERATED SPEC\n")


def check_comment_header(path, spec):
    try:
        expected = comment_header(spec).encode()
        with Path(path).open("rb") as source:
            if source.read(len(expected)) != expected:
                fail(path, f"missing or stale generated comment header (tools/gen --comment-header {spec.name})")
    except OSError as error:
        fail(path, str(error))


def production_sources(project):
    """Find candidate sources by the one-public-function-per-file convention."""
    sources = {}
    for path in sorted((project.root / "src/x86_64-linux").rglob("*.asm")):
        if path.stem not in project.functions:
            continue
        if path.stem in sources:
            fail(path, f"multiple source files for {path.stem}")
        sources[path.stem] = regular_file(project.root, path.relative_to(project.root), path)
    return sources


PHASE0_FIXED_INPUTS = (
    "AGENTS.md", "LICENSE", "Makefile", "devenv.nix", "devenv.lock", "devenv.yaml",
    "docs/adr/0001-project-scope.md", "docs/plan.md", "docs/api-index.md",
    "docs/cookbook/phase0-contract.md", "docs/cookbook/specifications.md",
    "docs/cookbook/test-oracles.md", "docs/cookbook/verification.md",
    "build/include/c/string.h", "build/include/c/inttypes.h", ".github/CODEOWNERS", ".github/workflows/phase0.yml",
)


def phase0_input_paths(root):
    """Enumerate exactly the repository inputs covered by Phase 0 evidence."""
    root = Path(root).resolve()
    paths = {Path(relative) for relative in PHASE0_FIXED_INPUTS}
    paths.update(path.relative_to(root) for path in (root / ".github/workflows").glob("*.yml"))
    for directory in ("tools", "nix", "spec", "include/asm", "tests", "ext"):
        paths.update(path.relative_to(root) for path in (root / directory).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc")
    for directory in ("src", "apps"):
        paths.update(path.relative_to(root) for path in (root / directory).rglob("*.asm")
                     if path.is_file())
    return tuple(sorted(paths))
