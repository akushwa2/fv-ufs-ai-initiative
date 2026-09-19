# UFS Glossary & Primer (for engineers new to UFS)

Plain-language reference for terms used across the sighting database. When a record uses a term you
don't know, look it up here first. `TODO(wiki)` = authoritative spec/wiki link to add.

## The UFS stack (top → bottom)
- **Application layer** — SCSI-like commands from the OS storage driver.
- **UPIU** (UFS Protocol Information Unit) — the packet format for commands/responses/data.
- **UTP** (UFS Transport Protocol) — transport layer; manages request/response queues (UTRD/UTMRD).
- **Host Controller (UFSHCI)** — the silicon block the OS driver programs via MMIO registers (incl. `IS_`).
- **UniPro** — link/network layer (DME commands, power modes, error counters like UECPA/UECDL/UECN/UECT).
- **M-PHY** — physical layer; HS-Gear/Rate, lanes, hibernate (Hibern8/H8).
- **Interconnect / fabric (OCP / Sonics / PSF)** — on-die fabric carrying UFS transactions to memory/PMC.
- **PMC / power management** — controls package C-states (PKGC) and S0ix; consumes LTR hints.

## Key terms
- **PKGC (Package C-state)** — CPU/SoC deep-idle power states (e.g., PKGC6, PKGC10.x). Deeper = more
  power saved, longer wake latency. Limiting to **C0/C1** = shallow, fastest wake.
- **S0ix / S0i2.0–2.2** — modern low-power idle sub-states. Deeper (2.1/2.2) save more but need lower
  latency tolerance from all IPs.
- **LTR (Latency Tolerance Reporting)** — a message an IP sends the PMC saying "I can tolerate at most
  X µs of wake latency." If an IP **doesn't report LTR**, the PMC may go too deep and starve it.
- **D0 / D3** — device power states (D0 = on, D3 = off/low). Windows toggles these for UFS.
- **Hibern8 / H8** — UniPro/M-PHY link low-power hibernate state.
- **OCP fabric timeout** — the on-die fabric gives up waiting for a resource (core/ring/memory) →
  raises a fatal error. Central mechanism in pattern `ufs-fabric-timeout-on-pkgc`.
- **Posted vs non-posted transaction** — *posted* = fire-and-forget (no completion in trace);
  *non-posted* = expects a completion. A stuck non-posted read is a classic hang fingerprint.
- **MCA (Machine Check Architecture)** — CPU hardware error reporting; banks record error status.
- **THREE_STRIKE** — a core repeatedly failed to make forward progress (e.g., a stuck read) → fatal.
- **CATERROR** — catastrophic error signal / platform-fatal condition.
- **DPC_WATCHDOG_VIOLATION** — Windows bugcheck when a DPC (deferred procedure call) runs too long
  (here: UFS bus reset >20s).
- **PGCB (Power-Gate Control Block)** — the per-IP block that sequences power-gating, clock on/off and
  reset around IP wake/sleep. Has its own state machine and clock (the PGCB clock).
- **CDC (Clock-Domain Crossing)** — a signal passing between two unsynchronized clock domains. If an
  edge (e.g. a reset release) is asynchronous to the receiving clock it can cause **metastability**.
- **WARMRST** — warm-reset state of the PGCB state machine; exiting it forces the sideband-logic clock on.
- **IOSF2OCP bridge** — the bridge translating IOSF-SB transactions to the UFS OCP domain; hosts a fuse
  FSM that must complete the fuse pull before the controller can assert IP_ready.
- **Fuse pull / fuse-puller** — the boot-time sequence that reads (pulls) IP fuses into registers. Its
  FSM goes `fuse_pull_ready (001)` → `fuse_pull_done (006)`; stuck at `001` = pull never completed.
- **IP_ready** — signal the UFS controller asserts (after power+clocks+no-fuse-errors+fuse-pull-done)
  to tell PMC the IP is up. PMC waits on `ufs_ip_ready_status` at Phase-3 bootflow.
- **fscan_mode** — a scan/test-mode qualifier used in the fuse-puller RTL state transition; a glitch on
  it during the transition window can drop the fuse-pull request (leading theory for this bug).
- **PC:0005 / `pmc_arc_pc`** — PMC ARC program counter; stuck value (`0xb0548` / `PC:0005`) = PMC looping
  in Phase-3 bootflow waiting for IP_ready.

## Key registers / signals
- **`IS_` (Interrupt Status Register)** — UFSHCI status; the OS reads it to service requests.
  - **SBFES / HBFES** — fatal fabric-error status bits; set on OCP fabric timeout in this pattern.
    (**"HBFES"** as written in sightings = the spec's **`HCFES`** — see decode below.)
- **`ufs_ip_ready_status`** — PMC-visible bit that the UFS controller asserts when up; polled at Phase-3.
  In `ufs-fusepull-cdc-race-on-boot` it never asserts because fuse-pull is stuck.
- **`UFS_FUSE_REG1`** — UFS fuse register from which the UFS Device ID is derived; the PMC-FW WA writes
  **`0x3800`** here so PMC can match the PCIe endpoint device-ID without a real fuse pull.
- **fuse-pull FSM / IOSF2OCP bridge FSM** — in the bug: fuse-puller **Idle**, bridge stuck **"Fuse Pull
  Request"**, fuse-pull stuck **`001`** (not `006`). `SB_PMA_FSM_STATE` = `SB_FSM_FUSE_PUSH_DONE`.
- **UECPA / UECDL / UECN / UECT** — UniPro error counter/status registers (PHY Adapter / Data Link /
  Network / Transport). Often **unreadable (read 0) under CATERROR**.
- **PMC `ufsx2_pwr_sts` / `ufspw1_pwr_sts`** — UFS power-gating status; `0x1` = powered/not gated.

### `IS_` Interrupt Status — detailed decode
Source: `scc_ufs_top_registers_spec.pdf` (§1.2.3.7) + `MindShare_UFS_eLearning_vE1.pdf`.
- **Register:** UFSHC `IS`, MMIO **offset `20h`**, 32-bit, default `0000_0000h`, access **RW/1C**
  (write-1-to-clear). Spec: *"indicates pending interrupts that require service by the low-level
  driver firmware."*
- **Companion `IE` (Interrupt Enable), offset `24h`** — identical bit layout; an interrupt is raised
  only when the `IS` status bit **and** its matching `IE` enable bit are both set.

| Bit | Status (IS) | Enable (IE) | Meaning |
|-----|-------------|-------------|---------|
| 18 | CEFES | CEFEE | Crypto Engine Fatal Error Status |
| **17** | **SBFES** | SBFEE | **System Bus Fatal Error Status** |
| **16** | **HCFES** | HCFEE | **Host Controller Fatal Error Status** (sightings call this "HBFES") |
| 12 | UTPES | UTPEE | UTP Error Status |
| 11 | DFES | DFEE | Device Fatal Error Status |
| 10 | UCCS | UCCE | UIC Command Completion Status |
| 8 | ULSS | ULSSE | UIC Link Startup Status |
| 0 | UTRCS | — | UTP Transfer Request Completion Status |

- **SBFES — System Bus Fatal Error Status (bit 17).** Spec verbatim: *"Indicates that the DWC_ufshc
  core encountered a system bus error that it cannot recover from (such as a bad software pointer).
  When the error occurs, the DWC_ufshc core is stopped and both UTRRSR and UTMRRSR registers are
  cleared to 0 by the core."* → An **OCP/Sonics fabric timeout is exactly this class** of unrecoverable
  system-bus error.
- **HCFES — Host Controller Fatal Error Status (bit 16).** Spec verbatim: *"Indicates that the
  DWC_ufshc core encountered a fatal error that it cannot recover from. When the error occurs, the core
  is stopped and both UTRRSR and UTMRRSR are cleared to 0. The host application must reset the DWC_ufshc
  core."*
- **Naming note:** neither the register spec nor the MindShare training defines an **"HBFES"** / "Host
  Bus Fatal Error." IS bit 16 is **`HCFES` (Host Controller Fatal Error Status)**. Treat sighting
  "HBFES" as **HCFES** unless a vendor doc proves otherwise.
- **Why it means a hang:** any fatal bit (SBFES/HCFES/…) **stops the core** and clears the run-stop
  registers (UTRLRSR/UTMRLRSR) → all queued transfers die → the OS's downstream `IS_` read never
  completes and recovery needs a full controller reset (the >20s UFS bus reset → DPC watchdog).

## "Normal vs fault" quick reference
| Thing | Healthy | Fault (this pattern) |
|-------|---------|----------------------|
| `IS_` | no fatal bits | **SBFES (bit17) + HCFES (bit16) set** |
| PSF trace | transactions complete | last `IS_` read / PSF4→UFS **stuck** |
| MCA | no bank logged | **THREE_STRIKE** on core (e.g., CORE2 MLC) |
| Power entry | UFS gets resources in time | fabric times out during deep PKGC entry |
| UECPA/DL/N/T | readable, clean | unreadable / 0 under CAT error |

`TODO(wiki): link UFSHCI spec, UniPro/M-PHY spec, platform PKGC/S0ix & LTR design docs.`
