---
title: "covering comune: concurrent compiler construction"
layout: post
author: ash
excerpt: how does one write a multithreaded compiler, anyway?
---

*this is the first in a series of articles in which i'd like to focus on specific parts of the design and implementation of comune.*

one of my big frustrations with both Rust and C++ is compilation speeds. although a lot of that is down to outdated linkers making poor use of multi-core processors - on a related note, shoutouts to [mold](https://github.com/rui314/mold) - 