/* Adapt the upstream test entry to the ordinary freestanding crt1 ABI. */
int test_main(int argc, char **argv);

int main(int argc, char **argv)
{
    return test_main(argc, argv);
}
