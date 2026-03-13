package services

import (
	"strings"
	"sync"
	"time"
)

// CacheStore is a thread-safe in-process TTL cache backed by sync.Map.
// It is intentionally dependency-free — no Redis required.
// For horizontal scaling, replace with a Redis-backed implementation that
// satisfies the same Get / Set / Delete / DeletePrefix API.
type CacheStore struct {
	m sync.Map
}

type cacheEntry struct {
	data   []byte
	expiry time.Time
}

// Get returns the cached bytes for key, or (nil, false) if missing/expired.
func (c *CacheStore) Get(key string) ([]byte, bool) {
	v, ok := c.m.Load(key)
	if !ok {
		return nil, false
	}
	e := v.(cacheEntry)
	if time.Now().After(e.expiry) {
		c.m.Delete(key)
		return nil, false
	}
	return e.data, true
}

// Set stores bytes under key with a TTL duration.
func (c *CacheStore) Set(key string, data []byte, ttl time.Duration) {
	c.m.Store(key, cacheEntry{data: data, expiry: time.Now().Add(ttl)})
}

// Delete removes a single key.
func (c *CacheStore) Delete(key string) {
	c.m.Delete(key)
}

// DeletePrefix removes all keys that start with prefix.
func (c *CacheStore) DeletePrefix(prefix string) {
	c.m.Range(func(k, _ any) bool {
		if strings.HasPrefix(k.(string), prefix) {
			c.m.Delete(k)
		}
		return true
	})
}

// NewCacheStore returns an initialized, ready-to-use CacheStore.
func NewCacheStore() *CacheStore { return &CacheStore{} }
