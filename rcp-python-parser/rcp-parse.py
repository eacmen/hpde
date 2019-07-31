#!/usr/bin/env python3

import os
import sys
import csv
import struct

from sympy import *
from sympy.parsing.sympy_parser import parse_expr

MATH_CHANNELS = [ ("Math_Roll", -180, 180, "rad", 10, "(180/pi) * atan2(AccelX, sqrt(AccelY**2 + AccelZ**2))"),
                  ("Math_Roll2", -180, 180, "rad", 10, "(180/pi) * atan2(AccelX, AccelZ)")]



if __name__ == '__main__':
    headings = None
    heading_stats = { }
    values = [ ]
    expressions = { }
    for name,min,max,units,rate,eqn in MATH_CHANNELS:
        expr = parse_expr(eqn, evaluate=False)
        expressions[name] = expr
    with open(sys.argv[1], 'r') as rcpfile, open(sys.argv[2], 'w', newline='') as outfile:
        rcpwriter = csv.writer(outfile, delimiter = ',', quoting=csv.QUOTE_NONE, quotechar='',escapechar='\\')
        rcpreader = csv.reader(rcpfile, delimiter = ',', quoting=csv.QUOTE_NONE)
        for row in rcpreader:
            if headings is None:
                headings = { }
                col = 0
                for heading in row:
                    vals = tuple(next(csv.reader([heading, ], delimiter='|')))
                    (name, unit, min, max, rate) = vals
                    headings[name] = col
                    col += 1
                for (name,min,max,units,rate,eqn) in MATH_CHANNELS:
                    row.append(f'"{name}"|"{units}"|{min}|{max}|{rate}')
                rcpwriter.writerow(row)
            else:
                thisrow = { }
                for name,col in headings.items( ):
                    value = row[col]
                    if len(value) == 0:
                        continue
                    value = float(value)
                    thisrow[name] = value
                    if name not in heading_stats:
                        heading_stats[name] = (value, value, value)
                    else:
                        (min, max, avg) = heading_stats[name]
                        if value < min:
                            min = value
                        if value > max:
                            max = value
                        avg = (avg + value)/2
                        heading_stats[name] = (min, max, avg)
                values.append(thisrow)
                for name,min,max,units,rate,eqn in MATH_CHANNELS:
                    expr = expressions[name]
                    try:
                        result = float(expr.evalf(subs=thisrow))
                        row.append(f'{result:.2f}')
                    except TypeError:
                        row.append('')
                    rcpwriter.writerow(row)
                        
    
    print("Name\tMin\tMax\tAvg")
    for name, stats in heading_stats.items( ):
        (min, max, avg) = stats
        print(f"{name}\t{min:.02f}\t{max:.02f}\t{avg:.02f}")
"""
    for name,min,max,units,rate,eqn in MATH_CHANNELS:
        expr = parse_expr(eqn, evaluate=False)
        for row in values:
            try:
                result = float(expr.evalf(subs=row))
                print(result)
            except TypeError:
                pass
"""         