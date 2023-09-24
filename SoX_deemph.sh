#!/bin/bash
mkdir deemph; for a in *.flac; do sox -S "$a" "deemph/$a" deemph; done
