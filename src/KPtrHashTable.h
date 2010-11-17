#ifndef K_PTR_HASH_TABLE_H_
#define K_PTR_HASH_TABLE_H_

#import <boost/shared_ptr.hpp>
#import <tr1/unordered_map>
#import <libkern/OSAtomic.h>


template<class T> class KPtrHashTable {
 public:
 
  typedef typename boost::shared_ptr<T> Value;
  typedef typename std::tr1::unordered_map<void const* , Value > Map;
  typedef typename Map::value_type ValueType;
  typedef typename Map::const_iterator ConstIterator;
  typedef typename Map::iterator Iterator;

 protected:
  Map map_;
  OSSpinLock spinLock_;
  Value empty_;
 
 public:
  
  KPtrHashTable(size_t nbuckets=0) : map_(nbuckets), empty_() {
    spinLock_ = OS_SPINLOCK_INIT;
  }
  
  virtual ~KPtrHashTable() {
    OSSpinLockLock(&spinLock_);
    // TODO: release all
    OSSpinLockUnlock(&spinLock_);
  }
  
  inline Map &map() { return map_; }
  
  inline void put(void const *key, T *value) {
    map_.insert(ValueType(key, Value(value)));
  }
  
  inline T * get(void const *key) {
    Iterator it = map_.find(key);
    return (it != map_.end()) ? it->second.get() : NULL;
  }
  
  inline Value &getValue(void const *key) {
    Iterator it = map_.find(key);
    return (it != map_.end()) ? it->second : empty_;
  }
  
  inline void swap(KPtrHashTable<T>& right) {
    map_.swap(right.map_);
  }
  
  inline size_t size() const { return map_.size(); }
  
  inline void atomicSwap(KPtrHashTable<T>& right) {
    OSSpinLockLock(&spinLock_);
    swap(right);
    OSSpinLockUnlock(&spinLock_);
  }
};

#endif  // K_PTR_HASH_TABLE_H_
