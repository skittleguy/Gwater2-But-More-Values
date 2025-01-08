# GWater2 [![made with - mee++](https://img.shields.io/badge/made_with-mee%2B%2B-2ea44f)](https://)

## Table Of Contents
- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation-steps)
- [Technical Details](#technical-details)
- [Credits](#credits)
- [Extras](#extras)

## Overview
**GWater2** Is a fluid simulation mod for Garry's Mod. It adds the ability to spawn and create a multitude of different fluids that flow in real time.
Due to the complex nature of simulating and rendering fluid dynamics, the backend of this mod requires a binary module. See [Technical Details](#technical-details) for more information.

Installation steps can be found [here](#installation-steps)

## Features
**GWater2** comes with a bunch of SWEPs and Entities to mess with, and a menu to change fluid behavior (default key = G).
Multiplayer is supported, and menu options (fluid parameters) are synced.

## Requirements
> [!IMPORTANT]
> In order to run **GWater2** You MUST have a DirectX11 capable graphics card

A capable card must have:
`Nvidia Driver version 396.45` (or higher)
OR
`AMD Software version 16.9.1` (or higher)
OR
`Intel® Graphics version 15.33.43.4425` (or higher)

If this is all gibberish to you, essentially any graphics card manufactured later than 2012 will work just fine.

### Supported systems
✅ = Fully Supported__
⚠️ = Half Supported (Must be ran under proton)__
❌ = Not supported__
❔ = Untested__

| OS | GMod Branch | GPU | Supported |
| --- | --- | --- | --- |
| Windows | Any | Nvidia | ✅ |
| Windows | Any | AMD    | ✅ |
| Windows | Any | Intel  | ✅ |
| Linux   | Any | Nvidia | ⚠️ |
| Linux   | Any | AMD    | ⚠️ |
| Linux   | Any | Intel  | ❔ |
| MacOS   | Any | Mac    | ❔ |

## Installation Steps
TODO

## Technical details
Unlike most other Garry's mod addons, **GWater2** uses a binary module. Although powerful, the default GLua API isn't able to do everything required to simulate and render fluid dynamics.
Backend particle physics is calculated via [Nvidia FleX](https://github.com/NVIDIAGameWorks/FleX). A GPU accelerated particle system for liquids.
Custom shaders were created in HLSL, compiled using [ShaderCompile](https://github.com/SCell555/ShaderCompile), and are injected during runtime.

TODO: add more technical info

## Credits
| Meetric      | Main Developer |
| googer       | Menu rewrite, adv water gun, Wiremod support, Transporter |
| jn           | Water-player interactions, Forcefield entity |
| Xenthio      | Diffuse and lighting improvements, VVIS culling |
| MyUsername   | Linux help |
| Stickrpg     | Reaction force sigs |
| Mikey        | StarfallEx API |
| Joka         | Water gun icon |
| Spanky       | Particle stretching code |
| PotatoOS     | Quaternion math |
| AndrewEathan | GWater1 entities |
| Kodya        | Swimming code |
| Nvidia       | FleX library |

## Extras
Please consider checking out [Gelly](https://github.com/gelly-gmod/gelly), another GMod fluid addon made in parallel alongside **GWater2**