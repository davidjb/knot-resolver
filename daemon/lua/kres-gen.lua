local ffi = require('ffi')
--[[ This file is generated by ./kres-gen.sh ]] ffi.cdef[[

typedef struct knot_dump_style knot_dump_style_t;
extern const knot_dump_style_t KNOT_DUMP_STYLE_DEFAULT;
typedef void knot_db_t;
struct kr_cdb_api {};

typedef struct knot_mm {
	void *ctx, *alloc, *free;
} knot_mm_t;

typedef void *(*map_alloc_f)(void *, size_t);
typedef void (*map_free_f)(void *baton, void *ptr);
typedef void (*trace_log_f) (const struct kr_query *, const char *, const char *);
typedef void (*trace_callback_f)(struct kr_request *);
typedef enum {KNOT_ANSWER, KNOT_AUTHORITY, KNOT_ADDITIONAL} knot_section_t;
typedef struct {
	uint16_t pos;
	uint16_t flags;
	uint16_t compress_ptr[16];
} knot_rrinfo_t;
typedef unsigned char knot_dname_t;
typedef unsigned char knot_rdata_t;
typedef struct knot_rdataset knot_rdataset_t;
struct knot_rdataset {
	uint16_t rr_count;
	knot_rdata_t *data;
};
typedef struct knot_rrset knot_rrset_t;
typedef struct {
	struct knot_pkt *pkt;
	uint16_t pos;
	uint16_t count;
} knot_pktsection_t;
struct knot_pkt {
	uint8_t *wire;
	size_t size;
	size_t max_size;
	size_t parsed;
	uint16_t reserved;
	uint16_t qname_size;
	uint16_t rrset_count;
	uint16_t flags;
	knot_rrset_t *opt_rr;
	knot_rrset_t *tsig_rr;
	struct {
		uint8_t *pos;
		size_t len;
	} tsig_wire;
	knot_section_t current;
	knot_pktsection_t sections[3];
	size_t rrset_allocd;
	knot_rrinfo_t *rr_info;
	knot_rrset_t *rr;
	knot_mm_t mm;
	char _stub[]; /* TMP: do NOT replace yet (changed in libknot-2.6.0) */
};
typedef struct knot_pkt knot_pkt_t;
typedef struct {
	void *root;
	struct knot_mm *pool;
} map_t;
struct kr_qflags {
	_Bool NO_MINIMIZE : 1;
	_Bool NO_THROTTLE : 1;
	_Bool NO_IPV6 : 1;
	_Bool NO_IPV4 : 1;
	_Bool TCP : 1;
	_Bool RESOLVED : 1;
	_Bool AWAIT_IPV4 : 1;
	_Bool AWAIT_IPV6 : 1;
	_Bool AWAIT_CUT : 1;
	_Bool SAFEMODE : 1;
	_Bool CACHED : 1;
	_Bool NO_CACHE : 1;
	_Bool EXPIRING : 1;
	_Bool ALLOW_LOCAL : 1;
	_Bool DNSSEC_WANT : 1;
	_Bool DNSSEC_BOGUS : 1;
	_Bool DNSSEC_INSECURE : 1;
	_Bool DNSSEC_CD : 1;
	_Bool STUB : 1;
	_Bool ALWAYS_CUT : 1;
	_Bool DNSSEC_WEXPAND : 1;
	_Bool PERMISSIVE : 1;
	_Bool STRICT : 1;
	_Bool BADCOOKIE_AGAIN : 1;
	_Bool CNAME : 1;
	_Bool REORDER_RR : 1;
	_Bool TRACE : 1;
	_Bool NO_0X20 : 1;
	_Bool DNSSEC_NODS : 1;
	_Bool DNSSEC_OPTOUT : 1;
	_Bool NONAUTH : 1;
	_Bool FORWARD : 1;
	_Bool DNS64_MARK : 1;
	_Bool CACHE_TRIED : 1;
	_Bool NO_NS_FOUND : 1;
};
typedef struct {
	knot_rrset_t **at;
	size_t len;
	size_t cap;
} rr_array_t;
struct ranked_rr_array_entry {
	uint32_t qry_uid;
	uint8_t rank;
	uint8_t revalidation_cnt;
	_Bool cached : 1;
	_Bool yielded : 1;
	_Bool to_wire : 1;
	_Bool expiring : 1;
	knot_rrset_t *rr;
};
typedef struct ranked_rr_array_entry ranked_rr_array_entry_t;
typedef struct {
	ranked_rr_array_entry_t **at;
	size_t len;
	size_t cap;
} ranked_rr_array_t;
struct kr_zonecut {
	knot_dname_t *name;
	knot_rrset_t *key;
	knot_rrset_t *trust_anchor;
	struct kr_zonecut *parent;
	map_t nsset;
	knot_mm_t *pool;
};
typedef struct {
	struct kr_query **at;
	size_t len;
	size_t cap;
} kr_qarray_t;
struct kr_rplan {
	kr_qarray_t pending;
	kr_qarray_t resolved;
	struct kr_request *request;
	knot_mm_t *pool;
	uint32_t next_uid;
};
struct kr_request {
	struct kr_context *ctx;
	knot_pkt_t *answer;
	struct kr_query *current_query;
	struct {
		const knot_rrset_t *key;
		const struct sockaddr *addr;
		const struct sockaddr *dst_addr;
		const knot_pkt_t *packet;
		const knot_rrset_t *opt;
		_Bool tcp;
		size_t size;
	} qsource;
	struct {
		unsigned int rtt;
		const struct sockaddr *addr;
	} upstream;
	struct kr_qflags options;
	int state;
	ranked_rr_array_t answ_selected;
	ranked_rr_array_t auth_selected;
	ranked_rr_array_t add_selected;
	rr_array_t additional;
	_Bool answ_validated;
	_Bool auth_validated;
	struct kr_rplan rplan;
	int has_tls;
	trace_log_f trace_log;
	trace_callback_f trace_finish;
	knot_mm_t pool;
};
enum kr_rank {KR_RANK_INITIAL, KR_RANK_OMIT, KR_RANK_TRY, KR_RANK_INDET = 4, KR_RANK_BOGUS, KR_RANK_MISMATCH, KR_RANK_MISSING, KR_RANK_INSECURE, KR_RANK_AUTH = 16, KR_RANK_SECURE = 32};
struct kr_cache {
	knot_db_t *db;
	const struct kr_cdb_api *api;
	struct {
		uint32_t hit;
		uint32_t miss;
		uint32_t insert;
		uint32_t delete;
	} stats;
	uint32_t ttl_min;
	uint32_t ttl_max;
	struct timeval checkpoint_walltime;
	uint64_t checkpoint_monotime;
};

typedef int32_t (*kr_stale_cb)(int32_t ttl, const knot_dname_t *owner, uint16_t type,
				const struct kr_query *qry);
struct knot_rrset {
	knot_dname_t *_owner;
	uint16_t type;
	uint16_t rclass;
	knot_rdataset_t rrs;
	void *additional;
};
struct kr_nsrep {
	unsigned int score;
	unsigned int reputation;
	const knot_dname_t *name;
	struct kr_context *ctx;
	/* beware: hidden stub, to avoid hardcoding sockaddr lengths */
};
struct kr_query {
	struct kr_query *parent;
	knot_dname_t *sname;
	uint16_t stype;
	uint16_t sclass;
	uint16_t id;
	struct kr_qflags flags;
	struct kr_qflags forward_flags;
	uint32_t secret;
	uint16_t fails;
	uint16_t reorder;
	uint64_t creation_time_mono;
	uint64_t timestamp_mono;
	struct timeval timestamp;
	struct kr_zonecut zone_cut;
	struct kr_layer_pickle *deferred;
	uint32_t uid;
	struct kr_query *cname_parent;
	struct kr_request *request;
	kr_stale_cb stale_cb;
	struct kr_nsrep ns;
};
struct kr_context {
	struct kr_qflags options;
	knot_rrset_t *opt_rr;
	map_t trust_anchors;
	map_t negative_anchors;
	struct kr_zonecut root_hints;
	struct kr_cache cache;
	char _stub[];
};
const char *knot_strerror(int);
knot_dname_t *knot_dname_from_str(uint8_t *, const char *, size_t);
_Bool knot_dname_is_equal(const knot_dname_t *, const knot_dname_t *);
_Bool knot_dname_is_sub(const knot_dname_t *, const knot_dname_t *);
int knot_dname_labels(const uint8_t *, const uint8_t *);
int knot_dname_size(const knot_dname_t *);
char *knot_dname_to_str(char *, const knot_dname_t *, size_t);
uint16_t knot_rdata_rdlen(const knot_rdata_t *);
uint8_t *knot_rdata_data(const knot_rdata_t *);
size_t knot_rdata_array_size(uint16_t);
knot_rdata_t *knot_rdataset_at(const knot_rdataset_t *, size_t);
int knot_rrset_add_rdata(knot_rrset_t *, const uint8_t *, const uint16_t, const uint32_t, knot_mm_t *);
void knot_rrset_init_empty(knot_rrset_t *);
uint32_t knot_rrset_ttl(const knot_rrset_t *);
int knot_rrset_txt_dump(const knot_rrset_t *, char **, size_t *, const knot_dump_style_t *);
int knot_rrset_txt_dump_data(const knot_rrset_t *, const size_t, char *, const size_t, const knot_dump_style_t *);
uint32_t knot_rrsig_sig_expiration(const knot_rdataset_t *, size_t);
uint32_t knot_rrsig_sig_inception(const knot_rdataset_t *, size_t);
const knot_dname_t *knot_pkt_qname(const knot_pkt_t *);
uint16_t knot_pkt_qtype(const knot_pkt_t *);
uint16_t knot_pkt_qclass(const knot_pkt_t *);
int knot_pkt_begin(knot_pkt_t *, knot_section_t);
int knot_pkt_put_question(knot_pkt_t *, const knot_dname_t *, uint16_t, uint16_t);
const knot_rrset_t *knot_pkt_rr(const knot_pktsection_t *, uint16_t);
const knot_pktsection_t *knot_pkt_section(const knot_pkt_t *, knot_section_t);
knot_pkt_t *knot_pkt_new(void *, uint16_t, knot_mm_t *);
void knot_pkt_free(knot_pkt_t **);
int knot_pkt_parse(knot_pkt_t *, unsigned int);
struct kr_rplan *kr_resolve_plan(struct kr_request *);
knot_mm_t *kr_resolve_pool(struct kr_request *);
struct kr_query *kr_rplan_push(struct kr_rplan *, struct kr_query *, const knot_dname_t *, uint16_t, uint16_t);
int kr_rplan_pop(struct kr_rplan *, struct kr_query *);
struct kr_query *kr_rplan_resolved(struct kr_rplan *);
int kr_nsrep_set(struct kr_query *, size_t, const struct sockaddr *);
uint32_t kr_rand_uint(uint32_t);
void kr_pkt_make_auth_header(knot_pkt_t *);
int kr_pkt_put(knot_pkt_t *, const knot_dname_t *, uint32_t, uint16_t, uint16_t, const uint8_t *, uint16_t);
int kr_pkt_recycle(knot_pkt_t *);
int kr_pkt_clear_payload(knot_pkt_t *);
const char *kr_inaddr(const struct sockaddr *);
int kr_inaddr_family(const struct sockaddr *);
int kr_inaddr_len(const struct sockaddr *);
int kr_sockaddr_len(const struct sockaddr *);
uint16_t kr_inaddr_port(const struct sockaddr *);
int kr_straddr_family(const char *);
int kr_straddr_subnet(void *, const char *);
int kr_bitcmp(const char *, const char *, int);
int kr_family_len(int);
struct sockaddr *kr_straddr_socket(const char *, int);
int kr_ranked_rrarray_add(ranked_rr_array_t *, const knot_rrset_t *, uint8_t, _Bool, uint32_t, knot_mm_t *);
void kr_qflags_set(struct kr_qflags *, struct kr_qflags);
void kr_qflags_clear(struct kr_qflags *, struct kr_qflags);
int kr_zonecut_add(struct kr_zonecut *, const knot_dname_t *, const knot_rdata_t *);
void kr_zonecut_set(struct kr_zonecut *, const knot_dname_t *);
uint64_t kr_now();
knot_rrset_t *kr_ta_get(map_t *, const knot_dname_t *);
int kr_ta_add(map_t *, const knot_dname_t *, uint16_t, uint32_t, const uint8_t *, uint16_t);
int kr_ta_del(map_t *, const knot_dname_t *);
void kr_ta_clear(map_t *);
_Bool kr_dnssec_key_ksk(const uint8_t *);
_Bool kr_dnssec_key_revoked(const uint8_t *);
int kr_dnssec_key_tag(uint16_t, const uint8_t *, size_t);
int kr_dnssec_key_match(const uint8_t *, size_t, const uint8_t *, size_t);
]]
