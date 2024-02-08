/*
* Sargantana Tile Configuration Parameters
*/

`ifndef __SARGANTANA_TILE_CONF_SVH__
`define __SARGANTANA_TILE_CONF_SVH__

//  Overrides HPDcache Parameter: Number of words in the request data channels (request and response)
`ifndef CONF_HPDCACHE_REQ_WORDS
    `define CONF_HPDCACHE_REQ_WORDS 8 
`endif

`ifndef CONF_HPDCACHE_WBUF_WORDS
    `define CONF_HPDCACHE_WBUF_WORDS 1
`endif

`ifndef CONF_HPDCACHE_ACCESS_WORDS
    `define CONF_HPDCACHE_ACCESS_WORDS 8 
`endif



`endif

