
/* Derived from GNU diff 2.7, analyze.c et al.

   The basic idea is to consider two vectors as similar if, when
   transforming the first vector into the second vector through a
   sequence of edits (inserts and deletes of one element each),
   this sequence is short - or equivalently, if the ordered list
   of elements that are untouched by these edits is long.  For a
   good introduction to the subject, read about the "Levenshtein
   distance" in Wikipedia.

   The basic algorithm is described in:
   "An O(ND) Difference Algorithm and its Variations", Eugene Myers,
   Algorithmica Vol. 1 No. 2, 1986, pp. 251-266;
   see especially section 4.2, which describes the variation used below.

   The basic algorithm was independently discovered as described in:
   "Algorithms for Approximate String Matching", E. Ukkonen,
   Information and Control Vol. 64, 1985, pp. 100-118.

   Unless the 'find_minimal' flag is set, this code uses the TOO_EXPENSIVE
   heuristic, by Paul Eggert, to limit the cost to O(N**1.5 log N)
   at the price of producing suboptimal output for large inputs with
   many differences.  */

typedef struct editdist_ctx {
  // Vectors being compared.
  const unichar *xvec;
  const unichar *yvec;

  // The number of elements inserted or deleted.
  int xvec_edit_count;
  int yvec_edit_count;

  // Vector, indexed by diagonal, containing 1 + the X coordinate of the point
  // furthest along the given diagonal in the forward search of the edit matrix.
  int *fdiag;

  // Vector, indexed by diagonal, containing the X coordinate of the point
  // furthest along the given diagonal in the backward search of the edit
  // matrix.
  int *bdiag;

  #ifdef USE_HEURISTIC
  // This corresponds to the diff -H flag.  With this heuristic, for vectors
  // with a constant small density of changes, the algorithm is linear in the
  // vectors size.
  BOOL heuristic;
  #endif

  // Edit scripts longer than this are too expensive to compute.
  int too_expensive;

  // Snakes bigger than this are considered `big'.
  #define SNAKE_LIMIT 20
} editdist_ctx_t;

#define NOTE_DELETE(ctxt, xoff) ctxt->xvec_edit_count++
#define NOTE_INSERT(ctxt, yoff) ctxt->yvec_edit_count++

struct partition {
  // Midpoints of this partition
  int xmid;
  int ymid;

  // True if low half will be analyzed minimally.
  BOOL lo_minimal;

  // Likewise for high half.
  BOOL hi_minimal;
};

/* Find the midpoint of the shortest edit script for a specified portion
   of the two vectors.

   Scan from the beginnings of the vectors, and simultaneously from the ends,
   doing a breadth-first search through the space of edit-sequence.
   When the two searches meet, we have found the midpoint of the shortest
   edit sequence.

   If FIND_MINIMAL is true, find the minimal edit script regardless of
   expense.  Otherwise, if the search is too expensive, use heuristics to
   stop the search and report a suboptimal answer.

   Set PART->(xmid,ymid) to the midpoint (XMID,YMID).  The diagonal number
   XMID - YMID equals the number of inserted elements minus the number
   of deleted elements (counting only elements before the midpoint).

   Set PART->lo_minimal to true iff the minimal edit script for the
   left half of the partition is known; similarly for PART->hi_minimal.

   This function assumes that the first elements of the specified portions
   of the two vectors do not match, and likewise that the last elements do not
   match.  The caller must trim matching elements from the beginning and end
   of the portions it is going to specify.

   If we return the "wrong" partitions, the worst this can do is cause
   suboptimal diff output.  It cannot cause incorrect diff output.  */

static void diag(int xoff, int xlim, int yoff, int ylim,
                 bool find_minimal, struct partition *part,
                 editdist_ctx_t *ctxt) {
  int *const fd = ctxt->fdiag;       /* Give the compiler a chance. */
  int *const bd = ctxt->bdiag;       /* Additional help for the compiler. */
  const unichar *const xv = ctxt->xvec; /* Still more help for the compiler. */
  const unichar *const yv = ctxt->yvec; /* And more and more . . . */
  const int dmin = xoff - ylim;      /* Minimum valid diagonal. */
  const int dmax = xlim - yoff;      /* Maximum valid diagonal. */
  const int fmid = xoff - yoff;      /* Center diagonal of top-down search. */
  const int bmid = xlim - ylim;      /* Center diagonal of bottom-up search. */
  int fmin = fmid;
  int fmax = fmid;           /* Limits of top-down search. */
  int bmin = bmid;
  int bmax = bmid;           /* Limits of bottom-up search. */
  int c;                     /* Cost. */
  bool odd = (fmid - bmid) & 1; /* True if southeast corner is on an odd
                                 diagonal with respect to the northwest. */

  fd[fmid] = xoff;
  bd[bmid] = xlim;

  for (c = 1;; ++c)
  {
    int d;                 /* Active diagonal. */
    bool big_snake = false;

    /* Extend the top-down search by an edit step in each diagonal. */
    if (fmin > dmin)
      fd[--fmin - 1] = -1;
    else
      ++fmin;
    if (fmax < dmax)
      fd[++fmax + 1] = -1;
    else
      --fmax;
    for (d = fmax; d >= fmin; d -= 2)
    {
      int x;
      int y;
      int tlo = fd[d - 1];
      int thi = fd[d + 1];
      int x0 = tlo < thi ? thi : tlo + 1;

      for (x = x0, y = x0 - d;
           x < xlim && y < ylim && (xv[x] == yv[y]);
           x++, y++)
        continue;
      if (x - x0 > SNAKE_LIMIT)
        big_snake = true;
      fd[d] = x;
      if (odd && bmin <= d && d <= bmax && bd[d] <= x)
      {
        part->xmid = x;
        part->ymid = y;
        part->lo_minimal = part->hi_minimal = true;
        return;
      }
    }

    /* Similarly extend the bottom-up search.  */
    if (bmin > dmin)
      bd[--bmin - 1] = INT_MAX;
    else
      ++bmin;
    if (bmax < dmax)
      bd[++bmax + 1] = INT_MAX;
    else
      --bmax;
    for (d = bmax; d >= bmin; d -= 2)
    {
      int x;
      int y;
      int tlo = bd[d - 1];
      int thi = bd[d + 1];
      int x0 = tlo < thi ? tlo : thi - 1;

      for (x = x0, y = x0 - d;
           xoff < x && yoff < y && (xv[x - 1] == yv[y - 1]);
           x--, y--)
        continue;
      if (x0 - x > SNAKE_LIMIT)
        big_snake = true;
      bd[d] = x;
      if (!odd && fmin <= d && d <= fmax && x <= fd[d])
      {
        part->xmid = x;
        part->ymid = y;
        part->lo_minimal = part->hi_minimal = true;
        return;
      }
    }

    if (find_minimal)
      continue;

#ifdef USE_HEURISTIC
    /* Heuristic: check occasionally for a diagonal that has made lots
     of progress compared with the edit distance.  If we have any
     such, find the one that has made the most progress and return it
     as if it had succeeded.

     With this heuristic, for vectors with a constant small density
     of changes, the algorithm is linear in the vector size.  */

    if (200 < c && big_snake && ctxt->heuristic)
    {
      int best = 0;

      for (d = fmax; d >= fmin; d -= 2)
      {
        int dd = d - fmid;
        int x = fd[d];
        int y = x - d;
        int v = (x - xoff) * 2 - dd;

        if (v > 12 * (c + (dd < 0 ? -dd : dd)))
        {
          if (v > best
              && xoff + SNAKE_LIMIT <= x && x < xlim
              && yoff + SNAKE_LIMIT <= y && y < ylim)
          {
            /* We have a good enough best diagonal; now insist
             that it end with a significant snake.  */
            int k;

            for (k = 1; (xv[x - k] == yv[y - k]); k++)
              if (k == SNAKE_LIMIT)
              {
                best = v;
                part->xmid = x;
                part->ymid = y;
                break;
              }
          }
        }
      }
      if (best > 0)
      {
        part->lo_minimal = true;
        part->hi_minimal = false;
        return;
      }

      best = 0;
      for (d = bmax; d >= bmin; d -= 2)
      {
        int dd = d - bmid;
        int x = bd[d];
        int y = x - d;
        int v = (xlim - x) * 2 + dd;

        if (v > 12 * (c + (dd < 0 ? -dd : dd)))
        {
          if (v > best
              && xoff < x && x <= xlim - SNAKE_LIMIT
              && yoff < y && y <= ylim - SNAKE_LIMIT)
          {
            /* We have a good enough best diagonal; now insist
             that it end with a significant snake.  */
            int k;

            for (k = 0; (xv[x + k] == yv[y + k]); k++)
              if (k == SNAKE_LIMIT - 1)
              {
                best = v;
                part->xmid = x;
                part->ymid = y;
                break;
              }
          }
        }
      }
      if (best > 0)
      {
        part->lo_minimal = false;
        part->hi_minimal = true;
        return;
      }
    }
#endif /* USE_HEURISTIC */

    /* Heuristic: if we've gone well beyond the call of duty, give up
     and report halfway between our best results so far.  */
    if (c >= ctxt->too_expensive)
    {
      int fxybest;
      int fxbest;
      int bxybest;
      int bxbest;

      /* Find forward diagonal that maximizes X + Y.  */
      fxybest = -1;
      for (d = fmax; d >= fmin; d -= 2)
      {
        int x = MIN (fd[d], xlim);
        int y = x - d;
        if (ylim < y)
        {
          x = ylim + d;
          y = ylim;
        }
        if (fxybest < x + y)
        {
          fxybest = x + y;
          fxbest = x;
        }
      }

      /* Find backward diagonal that minimizes X + Y.  */
      bxybest = INT_MAX;
      for (d = bmax; d >= bmin; d -= 2)
      {
        int x = MAX (xoff, bd[d]);
        int y = x - d;
        if (y < yoff)
        {
          x = yoff + d;
          y = yoff;
        }
        if (x + y < bxybest)
        {
          bxybest = x + y;
          bxbest = x;
        }
      }

      /* Use the better of the two diagonals.  */
      if ((xlim + ylim) - bxybest < fxybest - (xoff + yoff))
      {
        part->xmid = fxbest;
        part->ymid = fxybest - fxbest;
        part->lo_minimal = true;
        part->hi_minimal = false;
      }
      else
      {
        part->xmid = bxbest;
        part->ymid = bxybest - bxbest;
        part->lo_minimal = false;
        part->hi_minimal = true;
      }
      return;
    }
  }
}


/*
 Compare in detail contiguous subsequences of the two vectors
 which are known, as a whole, to match each other.

 The subsequence of vector 0 is [XOFF, XLIM) and likewise for vector 1.

 Note that XLIM, YLIM are exclusive bounds.  All indices into the vectors
 are origin-0.

 If FIND_MINIMAL, find a minimal difference no matter how
 expensive it is.

 The results are recorded by invoking NOTE_DELETE and NOTE_INSERT.
*/
static void compareseq (int xoff, int xlim, int yoff, int ylim,
                        bool find_minimal, editdist_ctx_t *ctxt) {
  unichar const *xv = ctxt->xvec; /* Help the compiler.  */
  unichar const *yv = ctxt->yvec;

  /* Slide down the bottom initial diagonal.  */
  while (xoff < xlim && yoff < ylim && (xv[xoff] == yv[yoff])) {
    xoff++;
    yoff++;
  }

  /* Slide up the top initial diagonal. */
  while (xoff < xlim && yoff < ylim && (xv[xlim - 1] == yv[ylim - 1])) {
    xlim--;
    ylim--;
  }

  /* Handle simple cases. */
  if (xoff == xlim) {
    while (yoff < ylim) {
      NOTE_INSERT (ctxt, yoff);
      yoff++;
    }
  } else if (yoff == ylim) {
    while (xoff < xlim) {
      NOTE_DELETE (ctxt, xoff);
      xoff++;
    }
  } else {
    struct partition part;

    /* Find a point of correspondence in the middle of the vectors.  */
    diag (xoff, xlim, yoff, ylim, find_minimal, &part, ctxt);

    /* Use the partitions to split this problem into subproblems.  */
    compareseq (xoff, part.xmid, yoff, part.ymid, part.lo_minimal, ctxt);
    compareseq (part.xmid, xlim, part.ymid, ylim, part.hi_minimal, ctxt);
  }
}



/* NAME
        fstrcmp - fuzzy string compare

   SYNOPSIS
        double fstrcmp(const char *, const char *);

   DESCRIPTION
        The fstrcmp function may be used to compare two string for
        similarity.  It is very useful in reducing "cascade" or
        "secondary" errors in compilers or other situations where
        symbol tables occur.

   RETURNS
        double; 1.0 if the strings are entirly dissimilar, 0.0 if the
        strings are identical, and a number in between if they are
        similar.  */

double editdist_cmp(const unichar *string1, int string1len,
                    const unichar *string2, int string2len) {
  editdist_ctx_t ctxt;
  int i;
  size_t fdiag_len;
  int *buffer;

  /* set the info for each string.  */
  ctxt.xvec = string1;
  ctxt.yvec = string2;

  /* short-circuit obvious comparisons */
  if (string1len == 0 && string2len == 0)
    return 1.0;
  if (string1len == 0 || string2len == 0)
    return 0.0;

  /* Set TOO_EXPENSIVE to be approximate square root of input size,
     bounded below by 256.  */
  ctxt.too_expensive = 1;
  for (i = string1len + string2len;
       i != 0;
       i >>= 2)
    ctxt.too_expensive <<= 1;
  if (ctxt.too_expensive < 256)
    ctxt.too_expensive = 256;

  /* Allocate memory for fdiag and bdiag from a thread-local pool.  */
  fdiag_len = string1len + string2len + 3;
  buffer = (int *)CFAllocatorAllocate(kCFAllocatorDefault,
                                      fdiag_len * (2 * sizeof(int)), 0);
  ctxt.fdiag = buffer + string2len + 1;
  ctxt.bdiag = ctxt.fdiag + fdiag_len;

  /* Now do the main comparison algorithm */
  ctxt.xvec_edit_count = 0;
  ctxt.yvec_edit_count = 0;
  compareseq(0, string1len, 0, string2len, 0, &ctxt);

  /* The result is
        ((number of chars in common) / (average length of the strings)).
     This is admittedly biased towards finding that the strings are
     similar, however it does produce meaningful results.  */
  double r = 1.0 - ((double)(string1len + string2len
                             - ctxt.yvec_edit_count - ctxt.xvec_edit_count)
                    / (string1len + string2len));
  CFAllocatorDeallocate(kCFAllocatorDefault, buffer);
  return r;
}




#import "NSString-editdistance.h"

@implementation NSString (EditDistance)


- (double)editDistanceToString:(NSString*)otherString {
  if (otherString == nil)
    return 0.0;
  unichar *string1, *string2;

  int string1len = (int)MIN(INT_MAX, self.length); // since our storage is int
  int string2len = (int)MIN(INT_MAX, otherString.length);

  string1 = (unichar*)CFAllocatorAllocate(kCFAllocatorDefault,
                                          string1len * sizeof(unichar), 0);
  string2 = (unichar*)CFAllocatorAllocate(kCFAllocatorDefault,
                                          string2len * sizeof(unichar), 0);

  [self getCharacters:string1 range:NSMakeRange(0, string1len)];
  [otherString getCharacters:string2 range:NSMakeRange(0, string2len)];

  double distance = editdist_cmp(string1, string1len, string2, string2len);

  CFAllocatorDeallocate(kCFAllocatorDefault, string1);
  CFAllocatorDeallocate(kCFAllocatorDefault, string2);

  return distance;
}


@end
