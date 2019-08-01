#!/usr/bin/env python3

import os
import sys
import csv
import struct

from collections import OrderedDict

from sympy import *
from sympy.parsing.sympy_parser import parse_expr

import pandas as pd
import numpy as np

IGNORE_CHANNELS = ['MK20F0', 'MK20F1', 'MK20F2', 'MK20F3', 'MK20F4', 'MK20F5', 'MK20F6', 'MK20F7', 'Battery', 'CruisePlus', 'CruiseMinus']
MATH_CHANNELS = [ ("Math_Roll", -180, 180, "deg", 10, "(180/pi) * atan2(AccelX, sqrt(AccelY**2 + AccelZ**2))"),
                  ("Math_Roll2", -180, 180, "deg", 10, "(180/pi) * atan2(AccelX, AccelZ)")]



class RcpLog(object):

    def __init__(self, filename):
        self.df = pd.read_csv(filename, delimiter = ',', quoting=csv.QUOTE_NONE)
        # filter out the "undesirables"
        for col_name in self.df.columns.values:
            for ic in IGNORE_CHANNELS:
                if ic in col_name:
                    self.df = self.df.drop(columns=[col_name,])

        self.original_headings = RcpLog.get_column_names(list(self.df.columns.values))
        self.df.columns = list(self.original_headings.keys( ))
    
    def export(self, filename):
        with open(filename, 'w') as outfile:
            self.df.to_csv(outfile, 
                           index=False, 
                           header=list(self.original_headings.values( )), 
                           sep=',', 
                           quoting=csv.QUOTE_NONE, 
                           quotechar='',
                           escapechar='\\')
    
    def generate_maths(self, channels):
        for name,min,max,units,rate,eqn in channels:
            expr = parse_expr(eqn, evaluate=False)
            new_channel_values = [ ]
            for k, row in self.df.iterrows( ):
                try:
                    result = float(expr.evalf(subs=row.to_dict( )))
                except (TypeError, ValueError):
                    result = np.nan
                new_channel_values.append(result)
            self.df[name] = new_channel_values
            self.original_headings[name] = f'"{name}"|"{units}"|{min}|{max}|{rate}'


    @staticmethod
    def get_column_names(columns):
        result = OrderedDict( )
        for c in columns:
            vals = tuple(next(csv.reader([c, ], delimiter='|')))
            (name, unit, min, max, rate) = vals
            result[name] = c
        return result

if __name__ == '__main__':
    rl = RcpLog(sys.argv[1])
    rl.generate_maths(MATH_CHANNELS)
    rl.export(sys.argv[2])
