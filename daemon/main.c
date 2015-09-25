/*  Copyright (C) 2014 CZ.NIC, z.s.p.o. <knot-dns@labs.nic.cz>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <uv.h>

#include "contrib/ucw/mempool.h"
#include "contrib/ccan/asprintf/asprintf.h"
#include "lib/defines.h"
#include "lib/resolve.h"
#include "lib/dnssec.h"
#include "daemon/network.h"
#include "daemon/worker.h"
#include "daemon/engine.h"
#include "daemon/bindings.h"

/*
 * Globals
 */
static int g_interactive = 1;

/*
 * TTY control
 */
static void tty_read(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf)
{
	/* Set output streams */
	FILE *out = stdout, *outerr = stderr;
	uv_os_fd_t stream_fd = 0;
	uv_fileno((uv_handle_t *)stream, &stream_fd);
	if (stream_fd != STDIN_FILENO) {
		if (nread <= 0) { /* Close if disconnected */
			uv_close((uv_handle_t *)stream, (uv_close_cb) free);
			return;
		}
		uv_os_fd_t dup_fd = dup(stream_fd);
		if (dup_fd >= 0) {
			out = outerr = fdopen(dup_fd, "w");
		}
	}
	/* Execute */
	if (stream && buf && nread > 0) {
		char *cmd = buf->base;
		if (cmd[nread - 1] == '\n') {
			cmd[nread - 1] = '\0';
		}
		struct engine *engine = stream->data;
		lua_State *L = engine->L;
		int ret = engine_cmd(engine, cmd);
		const char *message = "";
		if (lua_gettop(L) > 0) {
			message = lua_tostring(L, -1);
		}
		fprintf(ret ? outerr : out, "%s\n> ", message);
		lua_settop(L, 0);
		free(buf->base);
	}
	fflush(out);
	/* Close if redirected */
	if (stream_fd != STDIN_FILENO) {
		fclose(out); /* outerr is the same */
	}

}

static void tty_alloc(uv_handle_t *handle, size_t suggested, uv_buf_t *buf) {
	buf->len = suggested;
	buf->base = malloc(suggested);
}

static void tty_accept(uv_stream_t *master, int status)
{
	uv_tcp_t *client = malloc(sizeof(*client));
	if (client) {
		 uv_tcp_init(master->loop, client);
		 if (uv_accept(master, (uv_stream_t *)client) != 0) {
			free(client);
			return;
		 }
		 client->data = master->data;
		 uv_read_start((uv_stream_t *)client, tty_alloc, tty_read);
		 /* Write command line */
		 uv_buf_t buf = { "> ", 2 };
		 uv_try_write((uv_stream_t *)client, &buf, 1);
	}
}

static void signal_handler(uv_signal_t *handle, int signum)
{
	uv_stop(uv_default_loop());
	uv_signal_stop(handle);
}

static const char *set_addr(char *addr, int *port)
{
	char *p = strchr(addr, '#');
	if (p) {
		*port = atoi(p + 1);
		*p = '\0';
	}

	return addr;
}

/*
 * Server operation.
 */

static void help(int argc, char *argv[])
{
	printf("Usage: %s [parameters] [rundir]\n", argv[0]);
	printf("\nParameters:\n"
	       " -a, --addr=[addr]    Server address (default: localhost#53).\n"
	       " -k, --keyfile=[path] File containing trust anchors (DS or DNSKEY).\n"
	       " -f, --forks=N        Start N forks sharing the configuration.\n"
	       " -v, --verbose        Run in verbose mode.\n"
	       " -V, --version        Print version of the server.\n"
	       " -h, --help           Print help and usage.\n"
	       "Options:\n"
	       " [rundir]             Path to the working directory (default: .)\n");
}

static struct worker_ctx *init_worker(uv_loop_t *loop, struct engine *engine, mm_ctx_t *pool, int worker_id)
{
	/* Load bindings */
	engine_lualib(engine, "modules", lib_modules);
	engine_lualib(engine, "net",     lib_net);
	engine_lualib(engine, "cache",   lib_cache);
	engine_lualib(engine, "event",   lib_event);
	engine_lualib(engine, "worker",  lib_worker);

	/* Create main worker. */
	struct worker_ctx *worker = mm_alloc(pool, sizeof(*worker));
	if(!worker) {
		return NULL;
	}
	memset(worker, 0, sizeof(*worker));
	worker->engine = engine,
	worker->loop = loop;
	loop->data = worker;
	worker_reserve(worker, MP_FREELIST_SIZE);
	/* Register worker in Lua thread */
	lua_pushlightuserdata(engine->L, worker);
	lua_setglobal(engine->L, "__worker");
	lua_getglobal(engine->L, "worker");
	lua_pushnumber(engine->L, worker_id);
	lua_setfield(engine->L, -2, "id");
	lua_pop(engine->L, 1);
	return worker;
}

static int run_worker(uv_loop_t *loop, struct engine *engine)
{
	/* Control sockets or TTY */
	auto_free char *sock_file = NULL;
	uv_pipe_t pipe;
	uv_pipe_init(loop, &pipe, 0);
	pipe.data = engine;
	if (g_interactive) {
		printf("[system] interactive mode\n> ");
		fflush(stdout);
		uv_pipe_open(&pipe, 0);
		uv_read_start((uv_stream_t*) &pipe, tty_alloc, tty_read);
	} else {
		(void) mkdir("tty", S_IRWXU|S_IRWXG);
		sock_file = afmt("tty/%ld", getpid());
		if (sock_file) {
			uv_pipe_bind(&pipe, sock_file);
			uv_listen((uv_stream_t *) &pipe, 16, tty_accept);
		}
	}
	/* Run event loop */
	uv_run(loop, UV_RUN_DEFAULT);
	if (sock_file) {
		unlink(sock_file);
	}
	return kr_ok();
}

int main(int argc, char **argv)
{
	int forks = 1;
	array_t(char*) addr_set;
	array_init(addr_set);
	const char *keyfile = NULL;

	/* Long options. */
	int c = 0, li = 0, ret = 0;
	struct option opts[] = {
		{"addr", required_argument,   0, 'a'},
		{"keyfile",required_argument, 0, 'k'},
		{"forks",required_argument,   0, 'f'},
		{"verbose",    no_argument,   0, 'v'},
		{"version",   no_argument,    0, 'V'},
		{"help",      no_argument,    0, 'h'},
		{0, 0, 0, 0}
	};
	while ((c = getopt_long(argc, argv, "a:f:k:vVh", opts, &li)) != -1) {
		switch (c)
		{
		case 'a':
			array_push(addr_set, optarg);
			break;
		case 'f':
			g_interactive = 0;
			forks = atoi(optarg);
			if (forks == 0) {
				log_error("[system] error '-f' requires number, not '%s'\n", optarg);
				return EXIT_FAILURE;
			}
			break;
		case 'k':
			keyfile = optarg;
			if (access(optarg, R_OK) != 0) {
				log_error("[system] keyfile '%s': not readable\n", optarg);
				return EXIT_FAILURE;
			}
			break;
		case 'v':
			log_debug_enable(true);
			break;
		case 'V':
			log_info("%s, version %s\n", "Knot DNS Resolver", PACKAGE_VERSION);
			return EXIT_SUCCESS;
		case 'h':
		case '?':
			help(argc, argv);
			return EXIT_SUCCESS;
		default:
			help(argc, argv);
			return EXIT_FAILURE;
		}
	}

	/* Switch to rundir. */
	if (optind < argc) {
		const char *rundir = argv[optind];
		if (access(rundir, W_OK) != 0) {
			log_error("[system] rundir '%s': not writeable\n", rundir);
			return EXIT_FAILURE;
		}
		ret = chdir(rundir);
		if (ret != 0) {
			log_error("[system] rundir '%s': %s\n", rundir, strerror(errno));
			return EXIT_FAILURE;
		}
	}

	kr_crypto_init();

	/* Fork subprocesses if requested */
	while (--forks > 0) {
		int pid = fork();
		if (pid < 0) {
			perror("[system] fork");
			return EXIT_FAILURE;
		}
		/* Forked process */
		if (pid == 0) {
			kr_crypto_reinit();
			break;
		}
	}

	/* Block signals. */
	uv_loop_t *loop = uv_default_loop();
	uv_signal_t sigint, sigterm;
	uv_signal_init(loop, &sigint);
	uv_signal_init(loop, &sigterm);
	uv_signal_start(&sigint, signal_handler, SIGINT);
	uv_signal_start(&sigterm, signal_handler, SIGTERM);
	/* Create a server engine. */
	mm_ctx_t pool = {
		.ctx = mp_new (4096),
		.alloc = (mm_alloc_t) mp_alloc
	};
	struct engine engine;
	ret = engine_init(&engine, &pool);
	if (ret != 0) {
		log_error("[system] failed to initialize engine: %s\n", kr_strerror(ret));
		return EXIT_FAILURE;
	}
	/* Create worker */
	struct worker_ctx *worker = init_worker(loop, &engine, &pool, forks);
	if (!worker) {
		log_error("[system] not enough memory\n");
		return EXIT_FAILURE;
	}
	/* Bind to sockets and run */
	for (size_t i = 0; i < addr_set.len; ++i) {
		int port = 53;
		const char *addr = set_addr(addr_set.at[i], &port);
		ret = network_listen(&engine.net, addr, (uint16_t)port, NET_UDP|NET_TCP);
		if (ret != 0) {
			log_error("[system] bind to '%s#%d' %s\n", addr, port, knot_strerror(ret));
			ret = EXIT_FAILURE;
		}
	}
	/* Start the scripting engine */
	if (ret == 0) {
		ret = engine_start(&engine);
		if (ret == 0) {
			if (keyfile) {
				auto_free char *cmd = afmt("trust_anchors.file = '%s'", keyfile);
				if (!cmd) {
					log_error("[system] not enough memory\n");
					return EXIT_FAILURE;
				}
				engine_cmd(&engine, cmd);
				lua_settop(engine.L, 0);
			}
			/* Run the event loop */
			ret = run_worker(loop, &engine);
		}
	}
	/* Cleanup. */
	array_clear(addr_set);
	engine_deinit(&engine);
	worker_reclaim(worker);
	mp_delete(pool.ctx);
	if (ret != 0) {
		ret = EXIT_FAILURE;
	}
	kr_crypto_cleanup();
	return ret;
}
