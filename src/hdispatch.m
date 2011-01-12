// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "hdispatch.h"
#import <dispatch/dispatch.h>

dispatch_source_t hd_timer_start(float interval, dispatch_queue_t queue,
                                 id block) {
  dispatch_source_t timer =
      dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                             queue ? queue : dispatch_get_main_queue());
  dispatch_source_set_event_handler(timer, (dispatch_block_t)block);
  dispatch_time_t startTime = dispatch_time(0, (int64_t)(interval*1000000.0));
  uint64_t intervalNanosec = (uint64_t)(interval*1000000.0);
  dispatch_source_set_timer(timer, startTime, intervalNanosec, 0);
  dispatch_set_context(timer, (void*)timer);
  dispatch_resume(timer);
  return timer;
}
