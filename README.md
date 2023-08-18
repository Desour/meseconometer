<!--
SPDX-FileCopyrightText: 2023 DS

SPDX-License-Identifier: CC0-1.0
-->

Meseconometer
-------------

![screenshot](https://raw.githubusercontent.com/DS-Minetest/meseconometer/master/screenshot.png)

Can be used to measure timings of mesecon signals in globalsteps.

This repo is hosted at Codeberg: https://codeberg.org/Desour/meseconometer

Usage / Example:
- Place a meseconometer and open its formspec by rightclicking it.
- Set the activation port (eg. A) and connect a mesecons receptor with this port (eg. a switch).
- Connect your circuit with the meseconometer (eg. a switch to port B and the same switch with a diode gate to port C).
- Actiave the activation port. The time when it gets activated will be step `0`. All other events are relative to this one.
- Send some signals via your circuit (in the example: enable the switch).
- Deactivate the activation port. The meseconometer will no longer receive events.
- Open the formspec of the meseconometer and look at the events. (In the example, port C should be activated exactly `2` steps after port B, as gates have a delay of 2 steps.)

todo list:
- Add a proper description and co.
- Maybe store the stepcounter in world-/modstorage. (Currently when you leave a meseconometer on and rejoin, the step number becomes very long.)
- Digiline support?
- Display real time?
- Allow to not reset the data every time the meseconometer is activated?
- Improve this list.
