/* hy300tool - minimal FEL/FES helper for the Magcubic HY300 "dark minimal" patch.
 *
 * MIT License. Uses libefex (MIT, github.com/YuzukiTsuru/libefex) for the USB/FEL protocol.
 * The boot-header structs in sunxi_hdr.h come from libefex's test/fes_flash.c (MIT).
 *
 * Commands (all read-only unless stated):
 *   wait-fel [seconds]                    wait until a device in FEL mode shows up
 *   extract-fes <firmware.img> <outdir>   pull fes1.fex + u-boot.fex out of the community IMAGEWTY firmware
 *                                         (and check their SHA-256); does not touch the device
 *   load <fes1.fex> <u-boot.fex>          FEL -> FES: runs fes1 and u-boot ONLY IN RAM (nothing written)
 *   status <manifest> <patch>             classify every patch segment on the device as original/applied/unknown
 *   backup <manifest> <restore.bin>       WRITES A LOCAL FILE ONLY: the device's current bytes for every segment
 *   apply <manifest> <patch> <restore.bin> [--dry-run]
 *                                         WRITES THE DEVICE: refuses unless every segment is original (or already
 *                                         patched); saves restore.bin first; verifies afterwards
 *   restore <manifest> <restore.bin>      WRITES THE DEVICE: puts the saved original bytes back
 *   diag [all]                            read-only USB troubleshooting (what libusb sees)
 *
 * Exit codes: 0 ok, 1 error, 2 usage, 3 device not in FES mode, 4 no device, 5 unexpected disk contents (nothing
 * written), 6 write failed, 7 verification failed.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#ifdef _WIN32
#include <windows.h>
#define SLEEP_S(s) Sleep((s) * 1000)
#else
#include <unistd.h>
#define SLEEP_S(s) sleep(s)
#endif
#include <libusb.h>
#include "efex-common.h"
#include "libefex.h"
#include "usb_layer.h"
#include "sunxi_hdr.h"

#define FES_OFFSET 40960u       /* FES address = disk LBA - 40960 (proven on this device) */
#define MIN_LBA 73728ull        /* never touch anything before the first GPT partition */
#define SUPER_LBA 599040ull     /* writes are confined to the 'super' partition on this device */
#define SUPER_SECS 6291456ull
#define SLICE_SECS 8192u        /* 4 MiB per transfer */

static const char *FES1_SHA = "14592c5f301ae8e57314c69a2f7d9b9e28eba65072a052d9c89ae15fb235127c";
static const char *UBOOT_SHA = "20171bc98d34929955ae3fae29be14ce3d430dd6d421c43ad4f81c2d47e6fe40";

/* ---------- SHA-256 (public-domain style, compact) ---------- */
typedef struct { uint32_t h[8]; uint64_t n; uint8_t b[64]; size_t l; } Sha;
static const uint32_t K[64] = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
#define ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
static void sha_blk(Sha *s, const uint8_t *p) {
	uint32_t w[64], a, b, c, d, e, f, g, h, t1, t2; int i;
	for (i = 0; i < 16; i++) w[i] = (uint32_t) p[i*4] << 24 | p[i*4+1] << 16 | p[i*4+2] << 8 | p[i*4+3];
	for (; i < 64; i++) w[i] = (ROR(w[i-2], 17) ^ ROR(w[i-2], 19) ^ (w[i-2] >> 10)) + w[i-7] + (ROR(w[i-15], 7) ^ ROR(w[i-15], 18) ^ (w[i-15] >> 3)) + w[i-16];
	a = s->h[0]; b = s->h[1]; c = s->h[2]; d = s->h[3]; e = s->h[4]; f = s->h[5]; g = s->h[6]; h = s->h[7];
	for (i = 0; i < 64; i++) {
		t1 = h + (ROR(e, 6) ^ ROR(e, 11) ^ ROR(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i];
		t2 = (ROR(a, 2) ^ ROR(a, 13) ^ ROR(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
		h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
	}
	s->h[0] += a; s->h[1] += b; s->h[2] += c; s->h[3] += d; s->h[4] += e; s->h[5] += f; s->h[6] += g; s->h[7] += h;
}
static void sha_init(Sha *s) {
	static const uint32_t i0[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
	memcpy(s->h, i0, sizeof i0); s->n = 0; s->l = 0;
}
static void sha_upd(Sha *s, const uint8_t *p, size_t n) {
	s->n += n;
	while (n) { size_t k = 64 - s->l; if (k > n) k = n; memcpy(s->b + s->l, p, k); s->l += k; p += k; n -= k; if (s->l == 64) { sha_blk(s, s->b); s->l = 0; } }
}
static void sha_hex(Sha *s, char out[65]) {
	uint64_t bits = s->n * 8; uint8_t pad = 0x80, z = 0, len[8]; int i;
	sha_upd(s, &pad, 1); while (s->l != 56) sha_upd(s, &z, 1);
	for (i = 0; i < 8; i++) len[i] = (uint8_t) (bits >> (56 - 8 * i));
	sha_upd(s, len, 8);
	for (i = 0; i < 8; i++) sprintf(out + i * 8, "%08x", s->h[i]);
}
static void sha_buf(const void *p, size_t n, char out[65]) { Sha s; sha_init(&s); sha_upd(&s, p, n); sha_hex(&s, out); }

/* ---------- helpers ---------- */
static struct sunxi_efex_ctx_t ctx;
static uint8_t *slurp(const char *path, size_t *n) {
	FILE *f = fopen(path, "rb"); if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(1); }
	fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *b = malloc(sz ? sz : 1); if (fread(b, 1, sz, f) != (size_t) sz) { fprintf(stderr, "short read %s\n", path); exit(1); }
	fclose(f); *n = sz; return b;
}
typedef struct { unsigned long long lba; unsigned secs; unsigned long long off; char orig[65], neu[65]; } Seg;
static Seg *SEG; static int NSEG;
static void load_manifest(const char *path) {
	FILE *f = fopen(path, "r"); char line[512]; if (!f) { fprintf(stderr, "cannot open manifest %s\n", path); exit(1); }
	SEG = calloc(4096, sizeof(Seg));
	while (fgets(line, sizeof line, f)) {
		Seg s; if (sscanf(line, "seg %llu %u %llu %64s %64s", &s.lba, &s.secs, &s.off, s.orig, s.neu) == 5) {
			if (s.lba < SUPER_LBA || s.lba + s.secs > SUPER_LBA + SUPER_SECS || s.lba < MIN_LBA) { fprintf(stderr, "manifest segment outside the super partition, refusing\n"); exit(1); }
			SEG[NSEG++] = s;
		}
	}
	fclose(f); if (!NSEG) { fprintf(stderr, "empty manifest\n"); exit(1); }
}
static int connect_fes(void) {
	if (sunxi_scan_usb_device(&ctx) || sunxi_usb_init(&ctx) || sunxi_efex_init(&ctx)) { fprintf(stderr, "no device found\n"); return 4; }
	if (ctx.resp.mode != DEVICE_MODE_SRV) { fprintf(stderr, "device is not in FES mode (run 'load' first)\n"); return 3; }
	return 0;
}
static int rd(unsigned long long lba, uint8_t *b, size_t n) { memset(b, 0xA5, n); return sunxi_efex_fes_up(&ctx, (const char *) b, n, (uint32_t) (lba - FES_OFFSET), 0); }
static int wr(unsigned long long lba, const uint8_t *b, size_t n) {
	if (lba < SUPER_LBA || lba + n / 512 > SUPER_LBA + SUPER_SECS) { fprintf(stderr, "guard: write outside super\n"); exit(99); }
	return sunxi_efex_fes_down(&ctx, (const char *) b, n, (uint32_t) (lba - FES_OFFSET), 0);
}
static int rd_seg(const Seg *s, uint8_t *dst) {      /* reads a whole segment (slices of 4 MiB) */
	for (unsigned d = 0; d < s->secs; d += SLICE_SECS) { unsigned n = s->secs - d > SLICE_SECS ? SLICE_SECS : s->secs - d; if (rd(s->lba + d, dst + (size_t) d * 512, (size_t) n * 512)) return -1; }
	return 0;
}
/* 0 = original, 1 = applied, 2 = unknown, -1 = read error */
static int classify(const Seg *s) {
	uint8_t *b = malloc((size_t) s->secs * 512); char h[65]; int r;
	if (rd_seg(s, b)) { free(b); return -1; }
	sha_buf(b, (size_t) s->secs * 512, h);
	r = !strcmp(h, s->orig) ? 0 : (!strcmp(h, s->neu) ? 1 : 2); free(b); return r;
}
static int survey(int *no, int *na, int *nu, int verbose) {
	*no = *na = *nu = 0;
	for (int i = 0; i < NSEG; i++) {
		int c = classify(&SEG[i]);
		if (c < 0) { fprintf(stderr, "read error on segment %d\n", i); return -1; }
		if (c == 0) (*no)++; else if (c == 1) (*na)++; else { (*nu)++; if (verbose) fprintf(stderr, "segment %d (LBA %llu) has unexpected contents\n", i, SEG[i].lba); }
	}
	return 0;
}

/* ---------- commands ---------- */
static int cmd_wait(int argc, char **argv) {
	int secs = argc > 0 ? atoi(argv[0]) : 600;
	for (int i = 0; i < secs; i++) {
		if (sunxi_scan_usb_device(&ctx) == EFEX_ERR_SUCCESS && sunxi_usb_init(&ctx) == EFEX_ERR_SUCCESS && sunxi_efex_init(&ctx) == EFEX_ERR_SUCCESS) {
			printf("FEL device found (mode 0x%04x)\n", ctx.resp.mode); sunxi_usb_exit(&ctx); return 0;
		}
		SLEEP_S(1);
	}
	fprintf(stderr, "no FEL device within %d s\n", secs); return 4;
}
static int cmd_diag(int argc, char **argv) {   /* read-only USB troubleshooting: lists what libusb can see and whether the HY300 can be opened */
	libusb_context *c = NULL; libusb_device **l; int r = libusb_init(&c);
	if (r) { fprintf(stderr, "libusb_init failed: %s\n", libusb_error_name(r)); return 1; }
	ssize_t n = libusb_get_device_list(c, &l); int found = 0;
	printf("libusb sees %d USB devices\n", (int) n);
	for (ssize_t i = 0; i < n; i++) {
		struct libusb_device_descriptor d; if (libusb_get_device_descriptor(l[i], &d)) continue;
		int fel = d.idVendor == 0x1f3a && d.idProduct == 0xefe8;
		if (fel) found = 1;
		if (fel || argc > 0) printf("  %04x:%04x%s\n", d.idVendor, d.idProduct, fel ? "  <-- Allwinner FEL device" : "");
		if (fel) { libusb_device_handle *h = NULL; int o = libusb_open(l[i], &h); printf("    open: %s\n", o ? libusb_error_name(o) : "ok"); if (!o) { int k = libusb_claim_interface(h, 0); printf("    claim interface 0: %s\n", k ? libusb_error_name(k) : "ok"); if (!k) libusb_release_interface(h, 0); libusb_close(h); } }
	}
	if (!found) printf("No 1f3a:efe8 device is visible to libusb (driver not WinUSB/libusb, cable, or the projector is not in FEL mode).\n");
	libusb_free_device_list(l, 1); libusb_exit(c); return found ? 0 : 4;
}
static int cmd_extract(int argc, char **argv) {
	if (argc < 2) return 2;
	FILE *f = fopen(argv[0], "rb"); if (!f) { fprintf(stderr, "cannot open %s\n", argv[0]); return 1; }
	uint8_t hdr[0x60]; if (fread(hdr, 1, 0x60, f) != 0x60 || memcmp(hdr, "IMAGEWTY", 8)) { fprintf(stderr, "not an IMAGEWTY firmware image\n"); return 1; }
	uint32_t n; memcpy(&n, hdr + 0x3C, 4); int found = 0;
	for (uint32_t i = 0; i < n; i++) {
		uint8_t h[0x400]; fseek(f, 0x400 + (long) i * 0x400, SEEK_SET); if (fread(h, 1, 0x400, f) != 0x400) break;
		char name[0x101]; memcpy(name, h + 0x24, 0x100); name[0x100] = 0; char *b = strrchr(name, '\\'); b = b ? b + 1 : name;
		const char *want = !strcmp(b, "fes1.fex") ? FES1_SHA : (!strcmp(b, "u-boot.fex") ? UBOOT_SHA : NULL); if (!want) continue;
		uint32_t sz, off; memcpy(&sz, h + 0x12C, 4); memcpy(&off, h + 0x134, 4);
		uint8_t *d = malloc(sz); fseek(f, off, SEEK_SET); if (fread(d, 1, sz, f) != sz) { fprintf(stderr, "short read\n"); return 1; }
		char hx[65]; sha_buf(d, sz, hx);
		if (strcmp(hx, want)) { fprintf(stderr, "%s has an unexpected SHA-256 (%s). This firmware is not the one the patch was made with.\n", b, hx); return 5; }
		char out[1024]; snprintf(out, sizeof out, "%s/%s", argv[1], b); FILE *o = fopen(out, "wb"); if (!o || fwrite(d, 1, sz, o) != sz) { fprintf(stderr, "cannot write %s\n", out); return 1; }
		fclose(o); printf("extracted %s (%u bytes, sha256 ok)\n", b, sz); found++; free(d);
	}
	fclose(f); if (found != 2) { fprintf(stderr, "fes1.fex and/or u-boot.fex not found in the image\n"); return 1; }
	return 0;
}
static int cmd_load(int argc, char **argv) {
	if (argc < 2) return 2; int ret; time_t t0 = time(NULL);
	if (sunxi_scan_usb_device(&ctx) || sunxi_usb_init(&ctx) || sunxi_efex_init(&ctx)) { fprintf(stderr, "no device found\n"); return 4; }
	if (ctx.resp.mode == DEVICE_MODE_FEL) {
		size_t n, un; uint8_t *f1 = slurp(argv[0], &n), *ub = slurp(argv[1], &un);
		const struct boot_file_head_t *h = (const struct boot_file_head_t *) f1; struct dram_param_info_t dp = {0};
		if ((ret = sunxi_efex_fel_write(&ctx, h->ret_addr, (const char *) &dp, sizeof dp)) || (ret = sunxi_efex_fel_write(&ctx, h->run_addr, (const char *) f1, n)) || (ret = sunxi_efex_fel_exec(&ctx, h->run_addr))) goto fail;
		SLEEP_S(1);
		if ((ret = sunxi_efex_fel_read(&ctx, h->ret_addr, (char *) &dp, sizeof dp))) goto fail;
		printf("fes1 ok (DRAM flag 0x%08x)\n", dp.dram_init_flag);
		struct uboot_head_t *uh = (struct uboot_head_t *) ub; uh->uboot_data.work_mode = WORK_MODE_USB_PRODUCT;
		if ((ret = sunxi_efex_fel_write(&ctx, uh->uboot_head.run_addr, (const char *) ub, un)) || (ret = sunxi_efex_fel_exec(&ctx, uh->uboot_head.run_addr))) goto fail;
		printf("u-boot running from RAM, waiting for the device to come back in FES mode (about 40 s)...\n"); fflush(stdout);
		sunxi_usb_exit(&ctx);
		for (int i = 0; i < 60; i++) {
			SLEEP_S(2);
			if (sunxi_scan_usb_device(&ctx) == EFEX_ERR_SUCCESS && sunxi_usb_init(&ctx) == EFEX_ERR_SUCCESS) {
				if (sunxi_efex_init(&ctx) == EFEX_ERR_SUCCESS && ctx.resp.mode == DEVICE_MODE_SRV) break;
				sunxi_usb_exit(&ctx);
			}
			if (i == 59) { fprintf(stderr, "device did not come back in FES mode\n"); return 4; }
		}
	}
	if (ctx.resp.mode != DEVICE_MODE_SRV) { fprintf(stderr, "unexpected mode 0x%04x\n", ctx.resp.mode); return 3; }
	uint32_t st = 0, fsz = 0; SLEEP_S(12);   /* same settling time as in the original tests */
	sunxi_efex_fes_query_storage(&ctx, &st);
	sunxi_efex_fes_flash_set_onoff(&ctx, &st, 0); sunxi_efex_fes_probe_flash_size(&ctx, &fsz);
	sunxi_efex_fes_flash_set_onoff(&ctx, &st, 1); ret = sunxi_efex_fes_probe_flash_size(&ctx, &fsz);
	printf("FES ready: storage type %u, %u sectors (%.2f GiB) after %lds\n", st, fsz, fsz * 512.0 / 1073741824.0, (long) (time(NULL) - t0));
	if (ret || fsz != 15269888u) { fprintf(stderr, "this does not look like a HY300 eMMC (expected 15269888 sectors)\n"); return 5; }
	sunxi_usb_exit(&ctx); return 0;
fail:
	fprintf(stderr, "error: %s\n", sunxi_efex_strerror(ret)); return 1;
}
static int cmd_status(int argc, char **argv) {
	if (argc < 1) return 2; load_manifest(argv[0]); int r = connect_fes(); if (r) return r;
	int no, na, nu; if (survey(&no, &na, &nu, 1)) return 1;
	printf("STATE %s original=%d applied=%d unknown=%d\n", nu ? "unknown" : (na == NSEG ? "applied" : (no == NSEG ? "original" : "mixed")), no, na, nu);
	return nu ? 5 : 0;
}
static int cmd_backup(int argc, char **argv) {
	if (argc < 2) return 2; load_manifest(argv[0]); int r = connect_fes(); if (r) return r;
	size_t total = 0; for (int i = 0; i < NSEG; i++) total += (size_t) SEG[i].secs * 512;
	uint8_t *all = calloc(total, 1); size_t pos = 0;
	for (int i = 0; i < NSEG; i++) { if (rd_seg(&SEG[i], all + pos)) { fprintf(stderr, "read error\n"); return 1; } pos += (size_t) SEG[i].secs * 512; }
	FILE *o = fopen(argv[1], "wb"); if (!o || fwrite(all, 1, total, o) != total) { fprintf(stderr, "cannot write %s\n", argv[1]); return 1; }
	fclose(o); printf("saved %zu bytes to %s\n", total, argv[1]); return 0;
}
static int write_seg(const Seg *s, const uint8_t *data) {
	for (unsigned d = 0; d < s->secs; d += SLICE_SECS) { unsigned n = s->secs - d > SLICE_SECS ? SLICE_SECS : s->secs - d; if (wr(s->lba + d, data + (size_t) d * 512, (size_t) n * 512)) return -1; SLEEP_S(1); }
	return 0;
}
static int verify_seg(const Seg *s, const char *want) {
	uint8_t *b = malloc((size_t) s->secs * 512); char h[65]; int ok;
	if (rd_seg(s, b)) { free(b); return 0; }
	sha_buf(b, (size_t) s->secs * 512, h); ok = !strcmp(h, want); free(b); return ok;
}
static int cmd_apply(int argc, char **argv) {
	if (argc < 3) return 2; int dry = argc > 3 && !strcmp(argv[3], "--dry-run"); load_manifest(argv[0]);
	size_t pn; uint8_t *patch = slurp(argv[1], &pn); char ph[65]; sha_buf(patch, pn, ph);
	FILE *mf = fopen(argv[0], "r"); char line[512], want[65] = ""; while (mf && fgets(line, sizeof line, mf)) if (sscanf(line, "patchsha256 %64s", want) == 1) break; if (mf) fclose(mf);
	if (strcmp(ph, want)) { fprintf(stderr, "patch file does not match the manifest (corrupt download?)\n"); return 5; }
	int r = connect_fes(); if (r) return r;
	int no, na, nu; if (survey(&no, &na, &nu, 1)) return 1;
	printf("survey: original=%d applied=%d unknown=%d (of %d segments)\n", no, na, nu, NSEG);
	if (nu) { fprintf(stderr, "ABORTED: this device does not match the firmware build the patch was made for. Nothing was written.\n"); return 5; }
	if (na == NSEG) { printf("Already applied. Nothing to do.\n"); return 0; }
	size_t total = 0; for (int i = 0; i < NSEG; i++) total += (size_t) SEG[i].secs * 512;
	FILE *rf = fopen(argv[2], "rb");
	if (rf) { fclose(rf); printf("keeping existing restore file %s\n", argv[2]); }
	else {
		if (no != NSEG) { fprintf(stderr, "ABORTED: device is partially patched and no restore file exists.\n"); return 5; }
		uint8_t *all = calloc(total, 1); size_t pos = 0;
		for (int i = 0; i < NSEG; i++) { if (rd_seg(&SEG[i], all + pos)) { fprintf(stderr, "read error\n"); return 1; } pos += (size_t) SEG[i].secs * 512; }
		if (!dry) { FILE *o = fopen(argv[2], "wb"); if (!o || fwrite(all, 1, total, o) != total) { fprintf(stderr, "cannot write %s\n", argv[2]); return 1; } fclose(o); printf("saved your original bytes to %s\n", argv[2]); }
	}
	if (dry) { printf("DRY RUN: all checks passed, nothing written.\n"); return 0; }
	printf("writing %d segments...\n", NSEG); time_t t0 = time(NULL);
	for (int i = 0; i < NSEG; i++) {
		if (write_seg(&SEG[i], patch + SEG[i].off)) { fprintf(stderr, "write failed on segment %d\n", i); return 6; }
		if (i % 10 == 9) printf("  %d/%d (%lds)\n", i + 1, NSEG, (long) (time(NULL) - t0));
	}
	SLEEP_S(8); printf("verifying...\n"); int bad = 0;
	for (int i = 0; i < NSEG; i++) if (!verify_seg(&SEG[i], SEG[i].neu)) {
		int ok = 0;
		for (int k = 0; k < 2 && !ok; k++) { printf("  segment %d did not stick, rewriting (try %d)\n", i, k + 1); write_seg(&SEG[i], patch + SEG[i].off); SLEEP_S(8); ok = verify_seg(&SEG[i], SEG[i].neu); }
		if (!ok) { bad++; fprintf(stderr, "segment %d still differs\n", i); }
	}
	if (bad) { fprintf(stderr, "VERIFICATION FAILED on %d segments. Run 'restore' with %s before powering on.\n", bad, argv[2]); return 7; }
	printf("OK: patch applied and verified (%d segments).\n", NSEG); return 0;
}
static int cmd_restore(int argc, char **argv) {
	if (argc < 2) return 2; load_manifest(argv[0]); size_t rn; uint8_t *rb = slurp(argv[1], &rn); size_t total = 0;
	for (int i = 0; i < NSEG; i++) total += (size_t) SEG[i].secs * 512;
	if (rn != total) { fprintf(stderr, "restore file has the wrong size\n"); return 5; }
	char h[65]; for (int i = 0; i < NSEG; i++) { sha_buf(rb + SEG[i].off, (size_t) SEG[i].secs * 512, h); if (strcmp(h, SEG[i].orig)) { fprintf(stderr, "restore file does not contain the original data (segment %d); it was made from a device that was not stock.\n", i); return 5; } }
	int r = connect_fes(); if (r) return r;
	for (int i = 0; i < NSEG; i++) if (write_seg(&SEG[i], rb + SEG[i].off)) { fprintf(stderr, "write failed on segment %d\n", i); return 6; }
	SLEEP_S(8); int bad = 0;
	for (int i = 0; i < NSEG; i++) if (!verify_seg(&SEG[i], SEG[i].orig)) {   /* the eMMC write is asynchronous: retry up to twice */
		int ok = 0;
		for (int k = 0; k < 2 && !ok; k++) { printf("  segment %d did not stick, rewriting (try %d)\n", i, k + 1); write_seg(&SEG[i], rb + SEG[i].off); SLEEP_S(8); ok = verify_seg(&SEG[i], SEG[i].orig); }
		if (!ok) { bad++; fprintf(stderr, "segment %d still differs\n", i); }
	}
	if (bad) { fprintf(stderr, "restore verification failed on %d segments\n", bad); return 7; }
	printf("OK: original bytes restored and verified.\n"); return 0;
}
int main(int argc, char **argv) {
	setvbuf(stdout, NULL, _IONBF, 0);
	if (argc < 2) { fprintf(stderr, "usage: hy300tool wait-fel|extract-fes|load|status|backup|apply|restore ...  (see source header)\n"); return 2; }
#ifdef _WIN32
	sunxi_efex_set_usb_backend(USB_BACKEND_LIBUSB);   /* the Zadig/WinUSB driver has no device-interface GUID, so use libusb */
#endif
	const char *c = argv[1]; int n = argc - 2; char **a = argv + 2; int r = 2;
	if (!strcmp(c, "wait-fel")) r = cmd_wait(n, a); else if (!strcmp(c, "extract-fes")) r = cmd_extract(n, a); else if (!strcmp(c, "load")) r = cmd_load(n, a);
	else if (!strcmp(c, "status")) r = cmd_status(n, a); else if (!strcmp(c, "backup")) r = cmd_backup(n, a); else if (!strcmp(c, "apply")) r = cmd_apply(n, a); else if (!strcmp(c, "restore")) r = cmd_restore(n, a); else if (!strcmp(c, "diag")) r = cmd_diag(n, a);
	if (r == 2) fprintf(stderr, "bad arguments for '%s'\n", c);
	return r;
}
