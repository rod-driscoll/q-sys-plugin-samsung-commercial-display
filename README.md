
# q-sys-plugin-samsung-commercial-display

This plugin is a modified version of the Q-Sys plugin "SamsungMDC1.3.0.1" taken from the QSys managed plugins, and modified to extend functionality.

Language: Lua\
Platform: Q-Sys

Source code location: <https://github.com/rod-driscoll/q-sys-plugin-samsung-commercial-display>

The original documentation has not been included in this repo to avoid accidental IP violation, original documentation can be downloaded with the original plugin using Q-Sys Designer Asset manager.

![Control tab](https://github.com/rod-driscoll/q-sys-plugin-samsung-commercial-display/blob/master/content/control.png)\

## Deploying code

Copy the *.qplug file into "%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins" then drag the plugin into a design.

## Developing code

Instructions and resources for Q-Sys plugin development is available at:

* <https://q-syshelp.qsc.com/DeveloperHelp/>
* <https://github.com/q-sys-community/q-sys-plugin-guide/tree/master>

Do not edit the *.qplug file directly, this is created using the compiler.
"plugin.lua" contains the main code.

### Development and testing

The files in "./DEV/" are for dev only and may not be the most current code, they were created from the main *.qplug file following these instructions for run-time debugging:\
[Debugging Run-time Code](https://q-syshelp.qsc.com/DeveloperHelp/#Getting_Started/Building_a_Plugin.htm?TocPath=Getting%2520Started%257C_____3)

## Features

All the features of the original module (v1.3.0.1) are available by downloading the original module in Q-Sys Designer Asset Manager.

Additional features include:

* Screen blank

## Changelog

20231229 v1.4.0 (*unofficial mod of v1.3.0.1) RRD

* added Screen blank commands

## Authors

Original author: Q-Sys\
Revision author: [Rod Driscoll](rod@theavitgroup.com.au)
