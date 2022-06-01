
`ifndef CACHE_INCLUDE_DEFS
`define CACHE_INCLUDE_DEFS

`define TAG_XLEN        20

// Tag Memory List
typedef struct packed {
    logic                             valid;
    logic                             dirty;
    logic [`TAG_XLEN-1:0]             tag;
} type_dcache_tag_mem_s;

// Tag Memory List
typedef struct packed {
    logic                             valid;
    logic [`TAG_XLEN-1:0]             tag;
} type_icache_tag_mem_s;

`endif
