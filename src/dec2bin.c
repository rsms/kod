// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#include "dec2bin.h"

const char *dec2bin(long decimal, int nbits) {
  int  k = 0, n = 0;
  int  neg_flag = 0;
  int  remain;
  char temp[80];
  static char binary[80] = {0};

  if (decimal < 0) {
    decimal = -decimal;
    neg_flag = 1;
  }

  do {
    remain    = decimal % 2;
    decimal   = decimal / 2;
    temp[k++] = remain ? '1' : '.';
  } while (decimal > 0);

  binary[n++] = neg_flag ? '-' : ' ';
  while (n <= nbits-k)
    binary[n++] = '.';
  while (k >= 0)
    binary[n++] = temp[--k];
  binary[n-1] = 0;

  return binary;
}
