#!/usr/bin/env python2

import json, sys
keys = ("key","crypt","nocomp","datashard","parityshard")
with open(sys.argv[1]) as f:
    cf = json.load(f)
    kvs = zip( keys, [ cf[k] for k in keys ] )
    fm = lambda v: v[0] if v[1] is True else "{0}={1}".format(*v)
    print ";".join([fm(v) for v in kvs])
    
