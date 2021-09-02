simple-practicemode
===================
## Intro

基于[**csgo-practice-mode**](https://github.com/splewis/csgo-practice-mode)，删减了部分内容，更好地适配[**csgowiki-pack**](https://github.com/hx-w/CSGOWiki-Plugins)

## Feature

- [x] 不再与[**csgo-pug-setup**](https://github.com/splewis/csgo-pug-setup)和[**get5**](https://github.com/splewis/get5)兼容。`simple-practicemode`是一个单独且纯粹的跑图插件。
- [x] 删除原跑图插件的**本地道具仓库**功能，`.nades`、`.cats`相关功能取消。因为`csgowiki-pack`已经具有部分道具合集的功能。
- [x] 重构`botmimic`插件，使其适配`sourcemod v1.11`语法，重构后的插件名/Libary名称为`botmimic_fix`。
- [x] 新增计时器面板功能，`.timers`或`。timers`开启，整合了三种计时器类型。
- [x] 新增`。command`指令触发方式，方便中文输入法用户避免频繁切换输入法。
- [x] 更全面友好的汉化内容。

## Compiling

necessary `.inc` needed

- [**sourcemod v1.10 stable**](https://www.sourcemod.net/downloads.php?branch=stable)
- [**smlib**](https://github.com/bcserv/smlib/tree/transitional_syntax)


compiled files:
- `botmimic_fix.smx`
- `csutils.smx`
- `practicemode.smx`
