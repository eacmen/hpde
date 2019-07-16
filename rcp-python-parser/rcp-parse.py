#!/usr/bin/env python3

import os
import sys
import csv
import struct



if __name__ == '__main__':
    headings = None
    outfile = open(sys.argv[2], 'wb')
    with open(sys.argv[1], 'r') as rcpfile:
        rcpreader = csv.reader(rcpfile)
        for row in rcpreader:
            if headings is None:
                headings = { }
                col = 0
                for heading in row:
                    vals = tuple(next(csv.reader([heading, ], delimiter='|')))
                    (name, unit, min, max, rate) = vals
                    headings[name] = col
                    col += 1
            else:
                f1 = row[headings['MK20F1']]
                f2 = row[headings['MK20F2']]
                speed = row[headings['Speed']]
                if len(f1) == 0 or len(f2) == 0:
                    continue
                #if int(f1) == 3735928559 or int(f2) == 3735928559:
                #    #fucking deadbeef in CAN really?
                #    continue
                
                outfile.write(struct.pack(">II", int(f1), int(f2)))
                #print("%d   %d" % (int(f1), int(f2)))
                print("%08x   %08x" % (int(f1), int(f2)))
                print("{:032b}   {:032b}".format(int(f1), int(f2)))
