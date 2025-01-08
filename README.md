# GWater2 [![made with - mee++](https://img.shields.io/badge/made_with-mee%2B%2B-2ea44f)](https://)
![waterflowing](https://github.com/user-attachments/assets/80888b54-62a9-47fa-9ca1-fae9a6ae453f)

**GWater2** Is a fluid simulation mod for Garry's Mod. It adds the ability to spawn and create a multitude of different liquids that flow in real time.\
Due to the complex nature of simulating and rendering fluid dynamics, the backend of this mod requires a binary module. See [Technical Details](#technical-details) for more information.

Installation steps can be found [here](#installation)

# Table of Contents
- [Overview](#gwater2)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Technical Details](#technical-details)
- [Compilation](#compilation)
- [Credits](#credits)
- [Extras](#extras)

# Features
**GWater2** comes with a bunch of SWEPs and Entities to mess with, and a menu to change fluid behavior.\
Multiplayer is supported, and menu options (fluid parameters) are synced.

- Cloth
- Reaction Forces
- Swimming
- Foam / bubbles
- Surface Smoothing
- Multiplayer support
- SENTs / Entities
- Menu
	- lots of options and preset saving
- Sound

TODO

# Requirements
> [!IMPORTANT]
> In order to run **GWater2** you MUST have a DirectX11 capable graphics card

A capable card must have:\
`Nvidia Driver version 396.45` (or higher)\
OR\
`AMD Software version 16.9.1` (or higher)\
OR\
`Intel® Graphics version 15.33.43.4425` (or higher)

If this is all gibberish to you, essentially any graphics card manufactured later than 2012 will work just fine.

### Supported systems
✅ = Fully Supported\
⚠️ = Half Supported (Must be ran under proton)\
❌ = Not supported\
❔ = Untested

| OS | GMod Branch | GPU | Supported |
| --- | --- | --- | --- |
| Windows | Any | Nvidia | ✅ |
| Windows | Any | AMD    | ✅ |
| Windows | Any | Intel  | ✅ |
| Linux   | Any | Nvidia | ⚠️ |
| Linux   | Any | AMD    | ⚠️ |
| Linux   | Any | Intel  | ❔ |
| MacOS   | Any | Mac    | ❔ |

# Installation
TODO

# Technical details
Unlike most other Garry's mod addons, **GWater2** uses a binary module. The GLua API, although impressive, isn't powerful enough to simulate and render fluid dynamics.

Backend particle physics is calculated via [Nvidia FleX](https://github.com/NVIDIAGameWorks/FleX), a GPU accelerated particle system for liquids.\
Custom shaders were created in HLSL, compiled using [ShaderCompile](https://github.com/SCell555/ShaderCompile), and are injected during runtime.

TODO

# Compilation
This repository is set up with a [github actions](https://github.com/meetric1/gwater2/actions), which automatically compiles new modules for you.\
Feel free to download new module versions from there

> [!WARNING]
>  This repo is quite large (upwards of 1 gb), as it includes some submodules needed for compilation

> [!WARNING]
> Extremely new versions of visual studio may cause errors during compilation. This can be fixed by manually altering the gmcommon source code or by using vs2019

If you wish to compile it yourself, simply follow these steps.
1. *Recursively* clone this repository into your desired folder. 
	- Example command: `git clone https://github.com/meetric1/gwater2 --recursive`
2. Download [premake5](https://premake.github.io/download)
	- If you are on Windows, add the executable to PATH or copy it into this repositories ./binary directory 
		- If copied correctly, premake5.exe should be in the same folder as premake5.lua
	- On Linux, you should just be able to install it via your package manager. If that doesn't work, just download it directly, chmod the executable, and place it into ./binary
3. CD into the repositories ./binary directory and run `premake5` with your desired build system. 
	- I use Visual Studio 2022, so I would do `premake5 vs2022`
	- Linux users would do `./premake5 gmake`
	- [List of supported build systems](https://premake.github.io/docs/Using-Premake#using-premake-to-generate-project-files)
		- I am honestly unsure how new your build system needs to be. I'd personally just make sure to use vs2015 or later
4. Now, build the project like normal.

> [!TIP]
> If you need help with compiling, feel free to look at the github workflkow source code

> [!NOTE]
> By default, this repo builds for the x86-64 branch of GMod. If you wish to compile for the main branch, you will need to remove the gmcommon submodule and *recursively* re-clone the main branch version found here https://github.com/danielga/garrysmod_common

> [!CAUTION]
> Although Linux builds successfully, it throws errors during runtime, which I do not know how to fix. (pls help)\
> See https://github.com/meetric1/gwater2/issues/1 for more information

# Credits
```
Meetric      | Main Developer
googer       | Menu rewrite, adv water gun, Wiremod support, Transporter
jn           | Water-player interactions, Forcefield entity
Xenthio      | Diffuse and lighting improvements, VVIS culling
MyUsername   | Linux help
Stickrpg     | Reaction force sigs
Mikey        | StarfallEx API
Joka         | Water gun icon
Spanky       | Particle stretching code
PotatoOS     | Quaternion math
AndrewEathan | GWater1 entities
Kodya        | Swimming code
Nvidia       | FleX library
```

# Extras
Please consider checking out [Gelly](https://github.com/gelly-gmod/gelly), another GMod fluid addon made in parallel alongside **GWater2**
