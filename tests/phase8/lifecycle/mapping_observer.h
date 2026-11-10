#ifndef OA_LIFECYCLE_MAPPING_OBSERVER_H
#define OA_LIFECYCLE_MAPPING_OBSERVER_H

struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;

static unsigned long startup_page_size(void)
{
    enum { AT_PAGESZ = 6 };
    for (const struct aux_entry *item = __al_auxv; item->type; ++item) {
        if (item->type == AT_PAGESZ)
            return item->value;
    }
    return 0;
}

#endif
