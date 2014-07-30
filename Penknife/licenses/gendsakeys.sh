#!/bin/bash
openssl gendsa <(openssl dsaparam 512) -out dsa_priv.pem
openssl dsa -in dsa_priv.pem -pubout -out dsa_pub.pem
