#!/bin/bash
echo Email: $1
echo License: $(echo $1 | rev | tr -d '\n' | openssl dgst -dss1 -sign dsa_priv.pem | openssl enc -base64)
