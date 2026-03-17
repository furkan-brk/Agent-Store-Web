package cache

import (
	"strings"
	"sync"
	"time"
)

// Store is a thread-safe in-process TTL cache backed by sync.Map.
type Store struct {
	m sync.Map
}

type cacheEntry struct {
	data   []byte
	expiry time.Time
}

// Get returns the cached bytes for key, or (nil, false) if missing/expired.
func (c *Store) Get(key string) ([]byte, bool) {
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
func (c *Store) Set(key string, data []byte, ttl time.Duration) {
	c.m.Store(key, cacheEntry{data: data, expiry: time.Now().Add(ttl)})
}

// Delete removes a single key.
func (c *Store) Delete(key string) {
	c.m.Delete(key)
}

// DeletePrefix removes all keys that start with prefix.
func (c *Store) DeletePrefix(prefix string) {
	c.m.Range(func(k, _ any) bool {
		if strings.HasPrefix(k.(string), prefix) {
			c.m.Delete(k)
		}
		return true
	})
}

// NewStore returns an initialized, ready-to-use Store.
func NewStore() *Store { return &Store{} }
