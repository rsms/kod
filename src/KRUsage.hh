<<<<<<< HEAD
// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.
=======
#ifndef K_RUSAGE_H_
#define K_RUSAGE_H_

#if KOD_WITH_K_RUSAGE

#include <deque>
>>>>>>> upstream/master

/*!
 * Record resource usage using getrusage(2)
 */
class KRUsage {
 public:
  typedef std::pair<struct rusage, std::string> sample_t;
  typedef std::deque<sample_t> samples_t;
  samples_t samples;

  explicit KRUsage(std::string label) { sample(label); }
  KRUsage() { sample("start"); }
  ~KRUsage() {}

  void reset(std::string label) {
    samples.clear();
    sample(label);
  }
  void reset() { reset("start"); }

  void sample(std::string label) {
    sample_t sample;
    sample.second = label;
    int r = getrusage(0, &(sample.first)); assert(r == 0);
    samples.push_back(sample);
  }

  static double tvToMs(const struct timeval &tv) {
    return (((double)tv.tv_sec)*1000.0) + (((double)tv.tv_usec)/1000.0);
  }

  void format(std::string &dst) {
    samples_t::iterator it = samples.begin(), end = samples.end();
    if (!samples.empty()) {
      sample_t &oldest_sample = samples.front();
      double oldest_utime = tvToMs(oldest_sample.first.ru_utime);
      double oldest_stime = tvToMs(oldest_sample.first.ru_stime);

      sample_t &prev_sample = oldest_sample;
      double prev_utime = oldest_utime;
      double prev_stime = oldest_stime;

      dst.append("user/system/combined (since start)\n");

      while (++it != end) {
        sample_t &sample = *it;
        char buf[1024];
        double utime = tvToMs(sample.first.ru_utime);
        double stime = tvToMs(sample.first.ru_stime);

        snprintf(buf, 1024, "  %s -> %s: %.4f/%.4f/%.4f "
                            "(->| %.4f/%.4f/%.4f) ms\n",
                 prev_sample.second.c_str(),
                 sample.second.c_str(),

                 utime - prev_utime,
                 stime - prev_stime,
                 (utime - prev_utime) + (stime - prev_stime),

                 utime - oldest_utime,
                 stime - oldest_stime,
                 (utime - oldest_utime) + (stime - oldest_stime));

        dst.append(buf);

        prev_sample = sample;
        prev_utime = utime;
        prev_stime = stime;
      }
    }
  }
};


#define krusage_begin(variable, start_label) \
  __block KRUsage *variable = new KRUsage(start_label)

#define krusage_end(variable, end_label, report_prefix) do { \
  (variable)->sample(end_label); \
  std::string rusageString = report_prefix; \
  (variable)->format(rusageString); \
  fputs(rusageString.c_str(), stderr); \
  delete (variable); \
} while(0)

#define krusage_sample(variable, label) (variable)->sample(label)


#else  // KOD_WITH_K_RUSAGE

#define krusage_begin(variable, start_label) ((void)0)
#define krusage_end(variable, end_label, report_prefix) ((void)0)
#define krusage_sample(variable, label) ((void)0)

#endif  // KOD_WITH_K_RUSAGE


#endif  // K_RUSAGE_H_
