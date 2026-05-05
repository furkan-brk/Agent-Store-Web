package agent

import (
	"strings"

	"github.com/agentstore/backend/pkg/models"
)

// fuzzyThreshold is the minimum Levenshtein similarity (0..1) for a typo to
// still count as a "near match" — tuned so a 2-edit transposition in a 6-7
// character word ("wziard" → "wizard", similarity 0.67) still scores. Garbage
// queries ("xxxxxx" vs "wizard", similarity ~0) stay below the bar.
const fuzzyThreshold = 0.6

// scoreAgent computes a weighted relevance score for an agent against a
// search query. Higher is better; an empty query returns 0.
//
// Weights match the v3.11.1 plan:
//
//	title       3×  (most authoritative signal)
//	tags        2×  (curator-controlled labels)
//	description 1×  (free-text noise floor)
//
// Multiple tokens are scored independently and summed. A token gets its
// full weight on an exact substring hit, or weight × similarity (capped
// at 1.0) on a fuzzy near-match against any whitespace-split chunk in the
// candidate field. The fuzzy fallback only kicks in for tokens of length
// >= 3 to avoid stop-word noise.
func scoreAgent(a models.Agent, query string) float64 {
	query = strings.TrimSpace(query)
	if query == "" {
		return 0
	}
	tokens := tokenize(query)
	if len(tokens) == 0 {
		return 0
	}

	title := strings.ToLower(a.Title)
	desc := strings.ToLower(a.Description)
	tagsJoined := strings.ToLower(strings.Join(a.Tags, " "))

	titleParts := strings.Fields(title)
	descParts := strings.Fields(desc)
	tagParts := strings.Fields(tagsJoined)

	// Pre-filter: only spend Levenshtein DP cycles on candidates whose title
	// has at least one literal token hit. Other candidates fall back to
	// substring-only scoring (Levenshtein disabled). This trims worst-case
	// CPU on broad fuzzy queries by 3-5x without losing relevant titles.
	allowFuzzy := false
	for _, tok := range tokens {
		if tok != "" && strings.Contains(title, tok) {
			allowFuzzy = true
			break
		}
	}

	var total float64
	for _, tok := range tokens {
		total += weightedHit(tok, title, titleParts, 3.0, allowFuzzy)
		total += weightedHit(tok, tagsJoined, tagParts, 2.0, allowFuzzy)
		total += weightedHit(tok, desc, descParts, 1.0, allowFuzzy)
	}
	return total
}

// weightedHit returns weight on substring hit, weight*similarity on fuzzy hit
// (>= fuzzyThreshold), 0 otherwise. Substring takes precedence so an exact
// match always outscores a typo of the same word.
//
// allowFuzzy lets the caller short-circuit Levenshtein for candidates that
// failed the title pre-filter — substring hits still count, but typo
// tolerance is disabled to cap worst-case CPU.
func weightedHit(tok, joined string, parts []string, weight float64, allowFuzzy bool) float64 {
	if tok == "" {
		return 0
	}
	if strings.Contains(joined, tok) {
		return weight
	}
	if !allowFuzzy {
		return 0
	}
	if len(tok) < 3 {
		return 0
	}
	var best float64
	for _, p := range parts {
		if p == "" {
			continue
		}
		s := levenshteinSimilarity(tok, p)
		if s > best {
			best = s
		}
	}
	if best >= fuzzyThreshold {
		return weight * best
	}
	return 0
}

// maxQueryTokens caps the number of distinct tokens we score per query to
// keep the Levenshtein DP work bounded. Beyond this, additional tokens add
// little signal and a lot of CPU.
const maxQueryTokens = 5

// tokenize lowercases the query, splits on whitespace, drops empty tokens,
// dedupes preserving first-seen order, and caps at maxQueryTokens. Inputs
// longer than 30 chars per token are truncated so the Levenshtein DP stays
// cheap.
func tokenize(q string) []string {
	q = strings.ToLower(strings.TrimSpace(q))
	if q == "" {
		return nil
	}
	raw := strings.Fields(q)
	seen := make(map[string]struct{}, len(raw))
	out := make([]string, 0, len(raw))
	for _, t := range raw {
		if len(t) > 30 {
			t = t[:30]
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		out = append(out, t)
		if len(out) >= maxQueryTokens {
			break
		}
	}
	return out
}

// levenshteinSimilarity returns 1 - dist/maxLen, where dist is the
// Levenshtein edit distance and maxLen is the length of the longer string.
// Result is in [0, 1]; identical strings return 1, completely different
// strings return 0. Inputs over 30 chars are truncated for cheap DP.
func levenshteinSimilarity(a, b string) float64 {
	if a == b {
		return 1
	}
	if a == "" || b == "" {
		return 0
	}
	if len(a) > 30 {
		a = a[:30]
	}
	if len(b) > 30 {
		b = b[:30]
	}
	ar := []rune(a)
	br := []rune(b)
	la, lb := len(ar), len(br)
	if la == 0 || lb == 0 {
		return 0
	}

	// Two-row DP — O(min(la,lb)) memory.
	prev := make([]int, lb+1)
	curr := make([]int, lb+1)
	for j := 0; j <= lb; j++ {
		prev[j] = j
	}
	for i := 1; i <= la; i++ {
		curr[0] = i
		for j := 1; j <= lb; j++ {
			cost := 1
			if ar[i-1] == br[j-1] {
				cost = 0
			}
			curr[j] = min3(curr[j-1]+1, prev[j]+1, prev[j-1]+cost)
		}
		prev, curr = curr, prev
	}
	dist := prev[lb]
	maxLen := max(la, lb)
	return 1.0 - float64(dist)/float64(maxLen)
}

func min3(a, b, c int) int {
	return min(min(a, b), c)
}

// rankBySimilarity orders agents by a similarity score against a source
// agent and returns the top `limit`. Source-character-type matches always
// score higher than the rarity-distance boost; ties break on save_count.
//
// Used by GetSimilar (T2) — kept in this file so the search/rank helpers
// share one home and the tests don't need to cross packages.
func rankBySimilarity(candidates []models.Agent, src models.Agent, limit int) []models.Agent {
	if limit <= 0 || len(candidates) == 0 {
		return nil
	}
	type scored struct {
		a models.Agent
		s float64
	}
	srcRarityRank := rarityRank(string(src.Rarity))
	out := make([]scored, 0, len(candidates))
	for _, c := range candidates {
		var s float64
		if strings.EqualFold(c.CharacterType, src.CharacterType) {
			s += 10
		}
		if strings.EqualFold(c.Subclass, src.Subclass) && c.Subclass != "" {
			s += 5
		}
		// Penalise rarity distance (closer = better). Max distance is 4
		// across {common, uncommon, rare, epic, legendary}.
		rd := abs(rarityRank(string(c.Rarity)) - srcRarityRank)
		s += float64(4-rd) * 0.5
		// Save count tiebreaker, scaled small so it doesn't dominate type/subclass.
		s += float64(c.SaveCount) * 0.001
		out = append(out, scored{a: c, s: s})
	}
	// Stable insertion sort — candidate sets are small (≤ limit*2).
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].s > out[j-1].s; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	if limit > len(out) {
		limit = len(out)
	}
	res := make([]models.Agent, 0, limit)
	for i := 0; i < limit; i++ {
		res = append(res, out[i].a)
	}
	return res
}

func rarityRank(r string) int {
	switch strings.ToLower(r) {
	case "common":
		return 0
	case "uncommon":
		return 1
	case "rare":
		return 2
	case "epic":
		return 3
	case "legendary":
		return 4
	}
	return 0
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
