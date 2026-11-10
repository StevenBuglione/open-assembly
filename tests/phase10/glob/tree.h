#ifndef OA_GLOB_FIXTURE_TREE_H
#define OA_GLOB_FIXTURE_TREE_H

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static int make_file(const char *path)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    return fd >= 0 && close(fd) == 0;
}

static int basic_tree(void)
{
    return mkdir("root", 0700) == 0 && mkdir("root/dir", 0700) == 0 &&
           make_file("root/a.txt") && make_file("root/B.txt") && make_file("root/.dot.txt") &&
           make_file("root/dir/d.txt") && make_file("root/dir/c.txt");
}

#endif
