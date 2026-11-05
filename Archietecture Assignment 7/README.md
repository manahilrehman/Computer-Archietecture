# Computer Architecture — Lab 7: Cache Memory Mapping Architectures
### Direct-Mapped and Fully Associative Caches

This directory contains the complete implementations of all 20 laboratory tasks investigating cache memory hierarchy mechanics, set indexing, replacement policies, cache thrashing, and memory access optimization.

---

## Table of Contents

| Task | Title | Architecture | Focus |
|:---:|:---|:---:|:---|
| [Task 1](task1.asm.txt) | Single-Line Spatial Locality & Cold Misses | Direct-Mapped | Spatial locality, line fetching (16 B block) |
| [Task 2](task2.asm.txt) | Stride-Induced Conflict Misses (Ping-Pong Thrashing) | Direct-Mapped | 1 KB capacity, stride collision, 100% miss rate |
| [Task 3](task3.asm.txt) | Loop Padding and Alignment Optimization | Direct-Mapped | 64-byte padding buffer, conflict elimination |
| [Task 4](task4.asm.txt) | Matrix Traversal: Row-Major vs. Column-Major | Direct-Mapped | 16x16 matrix, 32 B lines, spatial reuse comparison |
| [Task 5](task5.asm.txt) | Software Direct-Mapped Cache Simulator | Direct-Mapped | Bit masking: Offset[3:0], Set[5:4], Tag[31:6] |
| [Task 6](task6.asm.txt) | Power-of-Two Stride Degradation | Direct-Mapped | 128 B cache, capacity collapse on power-of-two strides |
| [Task 7](task7.asm.txt) | Write-Through vs. Write-Back Flag Tracking | Direct-Mapped | Dirty-bit tracking, writeback bus transaction count |
| [Task 8](task8.asm.txt) | Instruction Cache Thrashing via Branch Bouncing | Direct-Mapped | 512 B L1 I-cache, colliding routine entry points |
| [Task 9](task9.asm.txt) | Block-Size Tradeoff Simulation | Direct-Mapped | Fixed 64 B capacity: 4x16 B vs. 2x32 B lines |
| [Task 10](task10.asm.txt) | Loop Tiling (Blocking) for a 1D Filter | Direct-Mapped | 3-tap moving average, cache blocking across passes |
| [Task 11](task11.asm.txt) | Tag Comparison Engine (Linear Search) | Fully Associative | 8 lines, Tag[31:4], O(1) vs. O(N) lookup search |
| [Task 12](task12.asm.txt) | Least Recently Used (LRU) Replacement | Fully Associative | 4 lines, 8-bit age counter array, eviction order |
| [Task 13](task13.asm.txt) | Conflict Immunity Test (Anti-Ping-Pong Test) | Fully Associative | 4 lines, zero conflict misses on colliding addresses |
| [Task 14](task14.asm.txt) | First-In, First-Out (FIFO) Replacement Queue | Fully Associative | Circular pointer `(ptr + 1) & 0x03` vs. LRU |
| [Task 15](task15.asm.txt) | Pseudo-Random Replacement Policy (LFSR) | Fully Associative | 8-bit Galois LFSR, victim mod 8, hit-rate variance |
| [Task 16](task16.asm.txt) | Optimal (Belady’s MIN) Offline Comparison | Fully Associative | 3 lines, forward clairvoyance vs. LRU online policy |
| [Task 17](task17.asm.txt) | Cache Invalidation and Maintenance Routines | Fully Associative | 16 lines, selective DMA flush & global context switch |
| [Task 18](task18.asm.txt) | Pathological Cyclic Thrashing (Capacity vs. Conflict)| Fully Associative | 4 lines, N=5 cyclic blocks, 0% hit rate under LRU |
| [Task 19](task19.asm.txt) | Instruction Overhead vs. Associativity Profiler | Comparison | Dynamic instruction counts: Direct (8 inst) vs FA (51 inst) |
| [Task 20](task20.asm.txt) | Unified Benchmark: Working-Set Size Sweep | Both Models | 1 KB target, 256 B–4096 B footprint sweep, 10k random walk |

---

## Detailed Task Summaries

### Section 1: Direct-Mapped Cache Mechanics (Problems 1–10)

1. **Problem 1 (task1.asm.txt)**: Demonstrates that when `array[0]` is accessed, an entire 16-byte block (4 words) is brought into cache (compulsory/cold miss). Subsequent accesses to `array[1]`, `array[2]`, and `array[3]` result in cache hits due to spatial locality.
2. **Problem 2 (task2.asm.txt)**: Demonstrates stride-induced conflict misses (ping-pong thrashing). Two arrays separated by exactly 1024 bytes (the cache capacity) map to the exact same set index. Interleaved reads alternate evictions, resulting in a 100% miss rate despite 96% of the cache remaining unused.
3. **Problem 3 (task3.asm.txt)**: Solves ping-pong thrashing by inserting a 64-byte dummy buffer between the arrays. The 4-set offset relocates `ArrayB` to set index 4, restoring spatial locality and lifting the hit rate from 0% to 75%.
4. **Problem 4 (task4.asm.txt)**: Compares row-major traversal (stride = 1 word = 4 bytes) against column-major traversal (stride = 16 words = 64 bytes) on a 16x16 matrix. Row-major achieves 87.5% hit rate; column-major collapses to 0% hit rate due to stride contention.
5. **Problem 5 (task5.asm.txt)**: Implements a bit-masking software simulator for a 4-line, 16 B/line cache. Uses `AND` and `SHR` instructions to extract Block Offset `[3:0]`, Set Index `[5:4]`, and Tag `[31:6]`.
6. **Problem 6 (task6.asm.txt)**: Examines power-of-two stride degradation. While stride = 16 B utilizes all 8 sets (100% capacity), stride = 128 B (equal to total cache capacity) maps solely to set 0, collapsing effective cache capacity to 1 block.
7. **Problem 7 (task7.asm.txt)**: Tracks memory bus write transactions. Write-Through incurs a bus write on every single store (100% traffic). Write-Back marks lines dirty and only triggers `mem_writeback()` on dirty line evictions, drastically reducing bus congestion.
8. **Problem 8 (task8.asm.txt)**: Demonstrates instruction cache thrashing ("branch bouncing"). Two functions (`FuncA` and `FuncB`) aligned to 512-byte boundaries map to the same I-cache line. Alternating calls continuously evict each other, producing a 100% I-cache miss spike.
9. **Problem 9 (task9.asm.txt)**: Evaluates block size tradeoffs under non-contiguous traversals (28-byte gaps). 4 lines × 16 B retains 4 working nodes in cache, whereas 2 lines × 32 B incurs severe conflict/capacity misses due to low line count and cache pollution.
10. **Problem 10 (task10.asm.txt)**: Implements loop tiling (blocking) for an iterative 3-tap moving average filter on an array 4x larger than cache. Naive sweeping flushes earlier elements on each pass; tiling retains 128-byte working segments in cache, eliminating capacity flushes.

---

### Section 2: Fully Associative Cache Mechanics (Problems 11–20)

11. **Problem 11 (task11.asm.txt)**: Implements a linear search tag engine over 8 fully associative slots. Contrasts the constant single-cycle $O(1)$ set lookup of direct-mapped caches with the $O(N)$ sequential software search, demonstrating why hardware requires parallel comparator circuits.
12. **Problem 12 (task12.asm.txt)**: Implements Least Recently Used (LRU) replacement using an 8-bit counter array. Validates the eviction order on sequence `{0x10, 0x20, 0x30, 0x40, 0x10, 0x50}`, where slot 1 is correctly selected as the oldest occupant.
13. **Problem 13 (task13.asm.txt)**: Proves conflict immunity in fully associative caches. The colliding address stream from Problem 2 (`0x000, 0x400, 0x800`) resides peacefully across separate slots, yielding 0 conflict misses and 100% steady-state hit rate.
14. **Problem 14 (task14.asm.txt)**: Compares FIFO (circular pointer `ptr = (ptr + 1) & 0x03`) with LRU. Shows that LRU protects frequently reused pages by resetting age counters upon hits, whereas FIFO blindly evicts by insertion time.
15. **Problem 15 (task15.asm.txt)**: Implements an 8-bit Galois Linear Feedback Shift Register (LFSR) with characteristic polynomial $x^8 + x^6 + x^5 + x^4 + 1$ (feedback mask `0xB4`). Measures hit-rate variance across 5 trials due to non-deterministic pseudo-random replacement.
16. **Problem 16 (task16.asm.txt)**: Compares online LRU against offline Belady’s MIN on reference string `{1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5}` in a 3-line cache. MIN achieves 5 hits (41.7%) versus LRU's 2 hits (16.7%), illustrating the optimality gap.
17. **Problem 17 (task17.asm.txt)**: Implements cache maintenance routines: selective line invalidation (`cache_invalidate_addr`) with dirty writeback for DMA safety, and global cache purge (`cache_invalidate_all`) for OS context switches.
18. **Problem 18 (task18.asm.txt)**: Explores pathological cyclic thrashing. When working set size $N = 5$ exceeds associativity $K = 4$, cyclic iteration yields 0% hit rate under LRU due to capacity misses, demonstrating that fully associative caches are vulnerable to capacity thrashing despite conflict immunity.
19. **Problem 19 (task19.asm.txt)**: Profiles dynamic instruction counts: Direct-Mapped lookup executes exactly 8 instructions ($O(1)$), whereas software Fully Associative search requires 7 to 51 instructions ($O(N)$), explaining the necessity of Content-Addressable Memory (CAM) in silicon.
20. **Problem 20 (task20.asm.txt)**: Implements a unified benchmark sweeping working-set footprint from 256 B to 4096 B with 10,000 random-walk accesses. Plots the characteristic inflection curve, identifying $C = 1024\text{ B}$ as the threshold where capacity misses begin to dominate both architectures.

---

## Assembly & Build Instructions

Each task is written in standard 32-bit x86 NASM assembly and targets the MinGW C runtime (`_main`, `_printf`, `_sprintf`):

```bash
# Assemble task:
nasm -f win32 task1.asm -o task1.obj

# Link with GCC (MinGW):
gcc -m32 task1.obj -o task1.exe

# Execute:
./task1.exe
```
