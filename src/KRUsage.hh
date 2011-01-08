#ifndef K_RUSAGE_H_
#define K_RUSAGE_H_

#include <deque>

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

  inline static double tvToMs(const struct timeval &tv) {
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

#endif  // K_RUSAGE_H_
