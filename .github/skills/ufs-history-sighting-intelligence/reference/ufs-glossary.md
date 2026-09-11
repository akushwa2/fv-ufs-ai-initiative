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

## Key registers / signals
- **`IS_` (Interrupt Status Register)** — UFSHCI status; the OS reads it to service requests.
  - **SBFES / HBFES** — fatal fabric-error status bits; set on OCP fabric timeout in this pattern.
- **UECPA / UECDL / UECN / UECT** — UniPro error counter/status registers (PHY Adapter / Data Link /
  Network / Transport). Often **unreadable (read 0) under CATERROR**.
- **PMC `ufsx2_pwr_sts` / `ufspw1_pwr_sts`** — UFS power-gating status; `0x1` = powered/not gated.

## "Normal vs fault" quick reference
| Thing | Healthy | Fault (this pattern) |
|-------|---------|----------------------|
| `IS_` | no fatal bits | **SBFES + HBFES set** |
| PSF trace | transactions complete | last `IS_` read / PSF4→UFS **stuck** |
| MCA | no bank logged | **THREE_STRIKE** on core (e.g., CORE2 MLC) |
| Power entry | UFS gets resources in time | fabric times out during deep PKGC entry |
| UECPA/DL/N/T | readable, clean | unreadable / 0 under CAT error |

`TODO(wiki): link UFSHCI spec, UniPro/M-PHY spec, platform PKGC/S0ix & LTR design docs.`
