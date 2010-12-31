#ifndef H_UNORDERED_MAP_
#define H_UNORDERED_MAP_

#import <tr1/functional>
#import <tr1/hashtable>
#import <tr1/unordered_map>

// You can define this as 0 to disable atomic *Sync methods (and drop HSpinLock
// dependency). When disabled, *Sync methods are simply aliases to their non-
// sync implementations.
#ifndef H_UNORDERED_MAP_WITH_ATOMIC
 #ifdef __SMP__
  #define H_UNORDERED_MAP_WITH_ATOMIC 0
 #else
  #define H_UNORDERED_MAP_WITH_ATOMIC 1
 #endif
#endif

#if H_UNORDERED_MAP_WITH_ATOMIC
 #import "HSpinLock.h"
 #define _HSLScope(sl) HSpinLock::Scope __hsls(sl)
#else
 #define _HSLScope(sl) do{}while(0)
#endif


template<typename K, typename T>
class HUnorderedMap {
 public:
  typedef typename std::tr1::unordered_map<K, T> map_type;
  typedef typename map_type::value_type entry_type;
  typedef typename map_type::const_iterator const_iterator;
  typedef typename map_type::iterator iterator;

 protected:
  map_type map_;

  #if H_UNORDERED_MAP_WITH_ATOMIC
  HSpinLock spinlock_;
  #endif

 public:

  HUnorderedMap(size_t nbuckets=0) : map_(nbuckets) { }

  virtual ~HUnorderedMap() { }

  inline map_type &map() { return map_; }

  inline void insert(K key, T value) { map_.insert(entry_type(key, value)); }

  inline iterator find(K key) { return map_.find(key); }
  inline const_iterator find(K key) const { return map_.find(key); }
  inline iterator findSync(K key) {
    _HSLScope(spinlock_);
    return map_.find(key);
  }

  inline void swap(map_type& other) { map_.swap(other.map_); }
  inline void swapSync(map_type& other) { _HSLScope(spinlock_); swap(other); }

  inline size_t size() const { return map_.size(); }
  inline size_t sizeSync() const { _HSLScope(spinlock_); return size(); }

  bool empty() const { return size() == 0; }
  bool emptySync() const { return sizeSync() == 0; }

  void clear() { map_.clear(); }
  void clearSync() { _HSLScope(spinlock_); clear(); }
};


#ifdef __OBJC__
#import "HObjCPtr.h"
/**
 * Unordered map which holds Objective-C objects.
 *
 * When an object is added, it receives a retain message and when an object is
 * removed it receives a release message.
 */
template<typename K, typename T = HObjCPtr>
class HUnorderedMapObjC : public HUnorderedMap<K, T> {
 public:
  typedef typename std::tr1::unordered_map<K, T> map_type;
  typedef typename map_type::value_type entry_type;
  typedef typename map_type::const_iterator const_iterator;
  typedef typename map_type::iterator iterator;

  inline void put(K key, id value) {
    this->map_.insert(entry_type(key, HObjCPtr(value)));
  }
  inline void putSync(K key, id value) {
    _HSLScope(this->spinlock_); put(key, value);
  }

  inline id get(K key) {
    iterator it = this->map_.find(key);
    return (it != this->map_.end()) ? it->second.get() : nil;
  }
  inline id getSync(K key) { _HSLScope(this->spinlock_); return get(key); }
};
#endif  // __OBJC__


// You can define this as 0 to disable boost support
#ifndef H_UNORDERED_MAP_WITH_BOOST
#define H_UNORDERED_MAP_WITH_BOOST 1
#endif

#if H_UNORDERED_MAP_WITH_BOOST
#import <boost/shared_ptr.hpp>
/**
 * Unordered map which holds C++ heap objects in boost::shared_ptr's
 */
template<typename K, typename T>
class HUnorderedMapSharedPtr : public HUnorderedMap<K, boost::shared_ptr<T> > {
 public:
  typedef typename boost::shared_ptr<T> value_type;
  typedef typename std::tr1::unordered_map<K, value_type> map_type;
  typedef typename map_type::value_type entry_type;
  typedef typename map_type::const_iterator const_iterator;
  typedef typename map_type::iterator iterator;

  inline void put(K key, T *value) {
    this->map_.insert(entry_type(key, value_type(value)));
  }
  inline void putSync(K key, T *value) {
    _HSLScope(this->spinlock_); put(key, value);
  }

  inline void put(K key, value_type &value) {
    this->map_.insert(entry_type(key, value));
  }
  inline void putSync(K key, value_type &value) {
    _HSLScope(this->spinlock_); put(key, value);
  }

  inline T *get(K key) {
    iterator it = this->map_.find(key);
    return (it != this->map_.end()) ? it->second.get() : NULL;
  }
  inline T *getSync(K key) { _HSLScope(this->spinlock_); return get(key); }

  inline value_type & getValue(K key) {
    iterator it = this->map_.find(key);
    return it->second;
  }
  inline value_type & getValueSync(K key) {
    _HSLScope(this->spinlock_); return getValue(key);
  }
};
#endif  // H_UNORDERED_MAP_WITH_BOOST


#undef _HSLScope

#endif  // H_UNORDERED_MAP_
