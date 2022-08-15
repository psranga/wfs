# WFS: Worst File System

## What

TLDR: Worst File System (WFS) is Just a Bunch Of *Network* Directories accessed
via a non-POSIX API.

Multiplatform, easy-to-setup, easy-to-use, reliable method to combine remote
machines' attached storage and present it as a single data store.

## Philosophy

Supporting hetereogenous computing platforms is good for all stakeholders.

Pick easy and reliable vs. all other design criteria when there is a conflict:

* P0: easy, reliable, simple code.
* P1: security, privacy, CPU/RAM usage.
* P2: latency, throughput, I/O operations per second, efficient storage usage.
* P3: efficiency over WAN and VPN links.

Semantic file system: Will support freeing space by re-encoding media at lower
quality instead of simply having to delete.

Does not provide a POSIX API: the idea is that you use the POSIX API to create
the file on small fast local storage (or RAM), and then use WFS to move it
elsewhere.

Tuned for: low-latency first-10MB-out, low-latency sub-10MB-writes, trivial API
for sub-1KB files, caller-provided QoS requirements for large reads and writes.

Tech stack: IPv6 first, DNS-SD, Lua, C++, C, ssh.

## Use cases

Moving files around between external disk drives formatted for different
systems. (Note to readers: Consider Paragon software for Mac and similar
software for Windows until WFS is ready for use).

## Why

Note to self: come up with a reasoning after finishing the project. :)

A man's home is his castle: Power home-computer-users are having too little fun.

Laziness, Hubris: Dunno, something about the way folder sharing happens today
leaves me feeling that someone "picked one" (vs "pick two").


## Scope

* In-home LAN
* High-speed links (100 Mbps, Gigabit, Wifi etc)
* Archival-type files
* P2: Should be runnable on DOS (to curb the temptation to overengineer)

## Status

* Low-level library that provides a non-POSIX API, and manages file chunks on
  attached storage (lcm.lua, testlcm.lua), and a higher-level layer than uses
  that to copy while files (wfs.lua, testwfs.lua).

* libcpp.cpp: Start of Lua bindings for functions in the standard C++ library
  (libcpp.cpp). I hope this is a reasonable compromise between portability and
  "batteries included".

  Lua has a clear philosophy that they do not want to provide as part of the
  core Lua binary anything that's not in the ISO C library (note it's C, not
  C++. And the ISO C library does not include POSIX headers like unistd.h).
  This is why has Lua has "fewer batteries included" than Python.

* Investigating whether to reinvent the wheel for the networking parts (DNS-SD,
  socket listening, HTTP vs DIY) or take more dependencies. My goal is to run
  WFS on my OpenWrt router, so I'm being careful about adding dependencies.

## Next Steps / Future Work

* Add RPC stuff so testwfs.lua can call a remote lcm.lua. Sketch: Do something
  bottle.py. Not sure if service discovery stuff should come next or the actual
  RPC plumbing. The service discovery stuff seems higher risk, esp if considering
  multiple platforms, so I'm leaning towards doing that first.

  But that might be overkill for an MVP.

## Dev Notes

* For this project, overall I like Lua's lightweightness.

* Lua lives up the hype wrt ease of writing C extensions.

  I was able to do it using only the info and code on the Lua web site (ref
  manual + PIL online). I've looked into doing this with Python and Tcl earlier
  in a different context. The Lua equivalent was easier.

* Shared libraries: how do they work? `-Wl,-rpath`, `-L`, `-shared`, `-l` and
  order-dependence of listed libraries all conspire to make this complicated. I
  bet each exists for a really good reason though.

  I couldn't figure out how to ask my custom-compiled gcc to link statically
  all dependencies supplied by it but not the platform. In the
  past I've used `readelf` to update the rpath setting in shared libs to "."
  after copying the needed .so files alongside the binary.

  Runtime loading of shared libraries *is a platform-dependent thing*, so it
  would be nice if gcc could do the heavy lifting for me (so I can focus on my
  project goals not command line trivia).

* Because I want to deploy on multiple platforms with low ceremony, I think it's
  going to be simpler for me to compile a custom Lua with my extensions compiled into
  that binary, than to create a shared library that excludes non-platform deps.

* Linux package management has jumped the shark? TLDR: all-or-nothing
  is unsatisfactory. I wanted to use gcc 12 to get maximum C++20 support, but my preferred OS
  is Linux Mint 21. It was simpler to recompile gcc from scratch than learn the various
  apt/dpkg commands.

  Probably going to standardize on homebrew on Linux. But it seems that brew
  doesn't install development headers. Need to look into that.

* GCC-12 doesn't support the new string formatting headers of the standard C++
  library. That made me sad -- it's an ergonomic improvement over `setbase()`,
  `setw()` etc IMO.

eof

