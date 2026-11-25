# gta6-pc-check

**Can your PC run VIctory, the open source attempt at GTA VI on PC?**

**Quick check in the browser, no install:** [cranefomo.github.io/gta6-pc-check](https://cranefomo.github.io/gta6-pc-check). It reads your graphics card's name, you tap your RAM, done. Nothing is uploaded.

**Exact check, one command in PowerShell:**

```powershell
irm https://raw.githubusercontent.com/Cranefomo/gta6-pc-check/main/check.ps1 | iex
```

Read-only. It downloads nothing, changes nothing, needs no admin rights and no game files. One file, read it first if you like.

## What it checks

Requirements come from the README of [VIctory](https://github.com/Marvisak/VIctory) and its AMD fork as of Nov 25, 2026.

| Stage | What it needs | Checked how |
|---|---|---|
| **boot** (menus, intro) | Windows 10/11 x64, CPU with AVX2, DirectX 12 GPU | Windows version, `IsProcessorFeaturePresent`, dxdiag |
| **world** (open world loads) | DirectX 12 Ultimate (mesh shaders), 32 GB RAM, 16 GB VRAM, 40 GB commit limit | dxdiag feature level 12_2, WMI |
| **play** | nobody yet | 3 to 5 fps on an RX 9070 XT with 64 GB RAM |

If something fails, it tells you why: no AVX2, no mesh shaders, not enough RAM, a small page file.

## Example output

```
  YOUR PC
  windows       Windows 11 x64 (build 26100)
  cpu           AMD Ryzen 7 7800X3D 8-Core Processor, AVX2 yes
  gpu           NVIDIA GeForce RTX 4080 SUPER, 16 GB
  dx feature    12_2,12_1,12_0,11_1,11_0
  ram           32 GB
  commit        48 GB limit, 29 GB free (RAM + page file)

  VERDICT
  OK  boot      menus and intro (Windows 10/11 x64, AVX2 CPU, DirectX 12 GPU)
  OK  world     load into the open world (DX12 Ultimate, 32 GB RAM, 16 GB VRAM, 40 GB commit)
  NO  play      nobody can yet: 3 to 5 fps on an RX 9070 XT with 64 GB RAM (Nov 25)
```
<sub>Example only. Your PC prints its own numbers.</sub>

## Options

```powershell
# already have a dxdiag report? skip the 20 second scan
.\check.ps1 -DxDiagFile C:\path\dxdiag.xml     # make one with: dxdiag /x C:\path\dxdiag.xml
```

## Honest notes

- This does not run GTA VI and does not get you any game files. VIctory needs your own copy of the game.
- VIctory has been tested on AMD cards only. Passing "world" here means your hardware meets what is known today, not that it will run.
- Requirements change daily. The project went from a dark screen to a lit world in two days.
- **Never run a "GTA VI PC port" exe from a post, a video or a Discord.** That is where the malware is.

## No guarantee

Free hobby script, provided "as is". Not affiliated with or endorsed by Rockstar Games, Take-Two, Microsoft, Sony, NVIDIA, AMD, Anthropic or the VIctory project.

## Credits

- [VIctory](https://github.com/Marvisak/VIctory) by Marvisak and contributors, GPL-3.0. Not included here, this script only reads your hardware.
- Also by me: [gta6-dlss5-smooth](https://github.com/Cranefomo/gta6-dlss5-smooth), smoother GTA VI from your PS5 on a PC, and [realfps](https://cranefomo.github.io/realfps).

Made by [@Cranefomo](https://x.com/Cranefomo). MIT license.
