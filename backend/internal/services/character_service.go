package services

import (
	"encoding/json"
	"math/rand"
	"strings"

	"github.com/agentstore/backend/internal/models"
)

type CharacterResult struct {
	Type     string            `json:"type"`
	Subclass string            `json:"subclass"`
	Name     string            `json:"name"`
	Rarity   string            `json:"rarity"`
	Colors   map[string]string `json:"colors"`
	Stats    map[string]int    `json:"stats"`
	Traits   []string          `json:"traits"`
}

type SynergyBonus struct {
	Name  string         `json:"name"`
	Bonus map[string]int `json:"bonus"`
}

var characterMap = map[string]CharacterResult{
	"wizard":     {Type: "wizard", Name: "Wizard", Colors: map[string]string{"primary": "#7C3AED", "secondary": "#1E1B4B", "accent": "#A78BFA"}, Stats: map[string]int{"intelligence": 90, "power": 75, "speed": 60, "creativity": 70, "defense": 40}},
	"strategist": {Type: "strategist", Name: "Strategist", Colors: map[string]string{"primary": "#DC2626", "secondary": "#78350F", "accent": "#FCD34D"}, Stats: map[string]int{"intelligence": 80, "power": 60, "speed": 50, "creativity": 65, "defense": 80}},
	"oracle":     {Type: "oracle", Name: "Oracle", Colors: map[string]string{"primary": "#D97706", "secondary": "#7C2D12", "accent": "#FDE68A"}, Stats: map[string]int{"intelligence": 95, "power": 50, "speed": 40, "creativity": 85, "defense": 45}},
	"guardian":   {Type: "guardian", Name: "Guardian", Colors: map[string]string{"primary": "#1D4ED8", "secondary": "#1E3A5F", "accent": "#93C5FD"}, Stats: map[string]int{"intelligence": 60, "power": 80, "speed": 45, "creativity": 30, "defense": 95}},
	"artisan":    {Type: "artisan", Name: "Artisan", Colors: map[string]string{"primary": "#EC4899", "secondary": "#0E7490", "accent": "#67E8F9"}, Stats: map[string]int{"intelligence": 70, "power": 50, "speed": 75, "creativity": 95, "defense": 35}},
	"bard":       {Type: "bard", Name: "Bard", Colors: map[string]string{"primary": "#16A34A", "secondary": "#713F12", "accent": "#BEF264"}, Stats: map[string]int{"intelligence": 75, "power": 45, "speed": 80, "creativity": 90, "defense": 30}},
	"scholar":    {Type: "scholar", Name: "Scholar", Colors: map[string]string{"primary": "#92400E", "secondary": "#D6D3D1", "accent": "#FEF3C7"}, Stats: map[string]int{"intelligence": 98, "power": 40, "speed": 35, "creativity": 80, "defense": 50}},
	"merchant":   {Type: "merchant", Name: "Merchant", Colors: map[string]string{"primary": "#B45309", "secondary": "#1E3A5F", "accent": "#FCD34D"}, Stats: map[string]int{"intelligence": 75, "power": 55, "speed": 70, "creativity": 60, "defense": 55}},
}

var keywordMap = map[string]string{
	"backend": "wizard", "golang": "wizard", "python": "wizard", "api": "wizard",
	"database": "wizard", "server": "wizard", "kod": "wizard", "code": "wizard",
	"developer": "wizard", "sql": "wizard", "java": "wizard", "programmer": "wizard",
	"plan": "strategist", "strategy": "strategist", "project": "strategist",
	"manager": "strategist", "roadmap": "strategist", "agile": "strategist",
	"scrum": "strategist", "task": "strategist", "stratejist": "strategist",
	"data": "oracle", "analytics": "oracle", "analiz": "oracle", "insight": "oracle",
	"statistics": "oracle", "ml": "oracle", "machine learning": "oracle",
	"security": "guardian", "güvenlik": "guardian", "firewall": "guardian",
	"pentest": "guardian", "infra": "guardian", "hacker": "guardian",
	"frontend": "artisan", "ui": "artisan", "ux": "artisan", "design": "artisan",
	"flutter": "artisan", "react": "artisan", "css": "artisan", "web": "artisan",
	"write": "bard", "yaz": "bard", "story": "bard", "creative": "bard",
	"content": "bard", "blog": "bard", "copy": "bard",
	"research": "scholar", "araştır": "scholar", "study": "scholar",
	"academic": "scholar", "science": "scholar", "learn": "scholar",
	"business": "merchant", "sales": "merchant", "marketing": "merchant",
	"growth": "merchant", "revenue": "merchant", "startup": "merchant",
}

// subclassKeywords: charType → subclass_name → keywords
var subclassKeywords = map[string]map[string][]string{
	"wizard": {
		"archmage":   {"architect", "senior", "system design", "enterprise", "principal"},
		"sorcerer":   {"fullstack", "versatile", "all", "everything", "general"},
		"hex_master": {"debug", "fix", "bug", "error", "patch", "troubleshoot"},
	},
	"strategist": {
		"war_commander": {"scale", "growth", "ambitious", "expand", "aggressive"},
		"tactician":     {"step", "process", "structured", "workflow", "systematic"},
		"diplomat":      {"collaborate", "team", "stakeholder", "align", "negotiate"},
	},
	"oracle": {
		"prophet":  {"predict", "forecast", "ml", "model", "future", "trend"},
		"analyst":  {"metrics", "kpi", "measure", "report", "dashboard"},
		"seer":     {"pattern", "visualization", "chart", "graph", "insight"},
	},
	"guardian": {
		"sentinel": {"pentest", "exploit", "hack", "vulnerability", "offensive"},
		"warden":   {"uptime", "monitor", "alert", "sre", "reliability"},
		"paladin":  {"compliance", "audit", "policy", "gdpr", "governance"},
	},
	"artisan": {
		"sculptor": {"animation", "3d", "motion", "interactive", "canvas"},
		"weaver":   {"component", "design system", "library", "storybook"},
		"painter":  {"visual", "aesthetic", "brand", "color", "palette"},
	},
	"bard": {
		"storyteller": {"narrative", "essay", "long", "article", "fiction"},
		"lyricist":    {"headline", "copy", "tagline", "hook", "viral"},
		"chronicler":  {"documentation", "guide", "manual", "readme", "wiki"},
	},
	"scholar": {
		"sage":      {"theory", "thesis", "academic", "paper", "philosophy"},
		"professor": {"teach", "tutorial", "course", "lesson", "explain"},
		"librarian": {"organize", "catalog", "archive", "curate", "index"},
	},
	"merchant": {
		"entrepreneur": {"startup", "mvp", "pivot", "launch", "bootstrapped"},
		"trader":       {"sales", "revenue", "funnel", "conversion", "deal"},
		"ambassador":   {"brand", "community", "viral", "influencer", "partner"},
	},
}

// subclassDisplayNames maps internal key to display name
var subclassDisplayNames = map[string]string{
	"archmage": "Archmage", "sorcerer": "Sorcerer", "hex_master": "Hex Master",
	"war_commander": "War Commander", "tactician": "Tactician", "diplomat": "Diplomat",
	"prophet": "Prophet", "analyst": "Analyst", "seer": "Seer",
	"sentinel": "Sentinel", "warden": "Warden", "paladin": "Paladin",
	"sculptor": "Sculptor", "weaver": "Weaver", "painter": "Painter",
	"storyteller": "Storyteller", "lyricist": "Lyricist", "chronicler": "Chronicler",
	"sage": "Sage", "professor": "Professor", "librarian": "Librarian",
	"entrepreneur": "Entrepreneur", "trader": "Trader", "ambassador": "Ambassador",
}

// defaultSubclass returns the first subclass for a given character type
var defaultSubclass = map[string]string{
	"wizard": "archmage", "strategist": "war_commander", "oracle": "prophet",
	"guardian": "sentinel", "artisan": "sculptor", "bard": "storyteller",
	"scholar": "sage", "merchant": "entrepreneur",
}

func DetermineCharacterType(prompt string) string {
	lower := strings.ToLower(prompt)
	scores := make(map[string]int)
	for keyword, charType := range keywordMap {
		if strings.Contains(lower, keyword) {
			scores[charType]++
		}
	}
	best, bestScore := "wizard", 0
	for charType, score := range scores {
		if score > bestScore {
			bestScore = score
			best = charType
		}
	}
	return best
}

// DetermineSubclass determines the subclass of a character type based on the prompt.
func DetermineSubclass(charType string, prompt string) string {
	lower := strings.ToLower(prompt)
	subclasses, ok := subclassKeywords[charType]
	if !ok {
		return randomSubclass(charType)
	}
	// Count keyword matches per subclass (fixed: score map lives outside inner loop)
	scores := make(map[string]int)
	for subclass, keywords := range subclasses {
		for _, kw := range keywords {
			if strings.Contains(lower, kw) {
				scores[subclass]++
			}
		}
	}
	best, bestScore := "", 0
	for subclass, score := range scores {
		if score > bestScore {
			bestScore = score
			best = subclass
		}
	}
	if best == "" {
		return randomSubclass(charType)
	}
	return best
}

// randomSubclass picks a random subclass for the given character type so that
// agents without strong keyword signals still get variety.
func randomSubclass(charType string) string {
	typeSubclasses := map[string][]string{
		"wizard":     {"archmage", "sorcerer", "hex_master"},
		"strategist": {"war_commander", "tactician", "diplomat"},
		"oracle":     {"prophet", "analyst", "seer"},
		"guardian":   {"sentinel", "warden", "paladin"},
		"artisan":    {"sculptor", "weaver", "painter"},
		"bard":       {"storyteller", "lyricist", "chronicler"},
		"scholar":    {"sage", "professor", "librarian"},
		"merchant":   {"entrepreneur", "trader", "ambassador"},
	}
	opts, ok := typeSubclasses[charType]
	if !ok || len(opts) == 0 {
		return "archmage"
	}
	return opts[rand.Intn(len(opts))]
}

func DetermineRarity(prompt string) models.CharacterRarity {
	score := len(prompt)/100 + countKeywords(prompt)*5
	switch {
	case score >= 50:
		return models.RarityLegendary
	case score >= 35:
		return models.RarityEpic
	case score >= 20:
		return models.RarityRare
	case score >= 10:
		return models.RarityUncommon
	default:
		return models.RarityCommon
	}
}

// MergeProfileIntoCharacterData merges an AgentProfile into an existing character_data JSON string.
// The profile is stored under the "profile" key, preserving all existing stat/color fields.
// If charDataJSON is empty or invalid, a fresh object is created.
func MergeProfileIntoCharacterData(charDataJSON string, profile *AgentProfile) string {
	if profile == nil {
		return charDataJSON
	}
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(charDataJSON), &data); err != nil {
		data = map[string]interface{}{}
	}
	data["profile"] = profile
	result, err := json.Marshal(data)
	if err != nil {
		return charDataJSON
	}
	return string(result)
}

func BuildCharacterData(charType, subclass string, rarity models.CharacterRarity, prompt string) (string, error) {
	base, ok := characterMap[charType]
	if !ok {
		base = characterMap["wizard"]
	}
	displaySubclass := subclassDisplayNames[subclass]
	if displaySubclass == "" {
		displaySubclass = subclass
	}
	result := CharacterResult{
		Type:     base.Type,
		Subclass: displaySubclass,
		Name:     base.Name,
		Rarity:   string(rarity),
		Colors:   base.Colors,
		Stats:    addVariance(base.Stats),
		Traits:   extractTraits(prompt),
	}
	data, err := json.Marshal(result)
	return string(data), err
}

// CalculateGuildSynergy calculates synergy bonuses for a guild and returns active bonuses + combined stat boost.
func CalculateGuildSynergy(types []string) ([]SynergyBonus, map[string]int) {
	bonuses := []SynergyBonus{}
	combined := map[string]int{}

	typeSet := map[string]bool{}
	for _, t := range types {
		typeSet[t] = true
	}

	// Pairwise synergies
	has := func(a, b string) bool { return typeSet[a] && typeSet[b] }

	if has("wizard", "oracle") {
		b := SynergyBonus{Name: "Data Sorcerer", Bonus: map[string]int{"intelligence": 15}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("guardian", "strategist") {
		b := SynergyBonus{Name: "Iron Fortress", Bonus: map[string]int{"defense": 20}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("artisan", "bard") {
		b := SynergyBonus{Name: "Creative Force", Bonus: map[string]int{"creativity": 20}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("scholar", "oracle") {
		b := SynergyBonus{Name: "Think Tank", Bonus: map[string]int{"intelligence": 15, "speed": 10}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("merchant", "strategist") {
		b := SynergyBonus{Name: "Market Dominator", Bonus: map[string]int{"power": 15}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("wizard", "guardian") {
		b := SynergyBonus{Name: "Secure Code", Bonus: map[string]int{"intelligence": 10, "defense": 10}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}
	if has("bard", "merchant") {
		b := SynergyBonus{Name: "Brand Engine", Bonus: map[string]int{"creativity": 15, "power": 10}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}

	// 4 different types → Legendary Assembly
	if len(typeSet) >= 4 {
		b := SynergyBonus{Name: "Legendary Assembly", Bonus: map[string]int{"intelligence": 10, "power": 10, "speed": 10, "creativity": 10, "defense": 10}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}

	// Same type (Twin Force) — majority type check
	typeCounts := map[string]int{}
	for _, t := range types {
		typeCounts[t]++
	}
	for _, count := range typeCounts {
		if count >= 2 {
			b := SynergyBonus{Name: "Twin Force", Bonus: map[string]int{"power": 25}}
			bonuses = append(bonuses, b)
			addBonus(combined, b.Bonus)
			break
		}
	}

	return bonuses, combined
}

func addBonus(target map[string]int, bonus map[string]int) {
	for k, v := range bonus {
		target[k] += v
	}
}

func countKeywords(prompt string) int {
	lower := strings.ToLower(prompt)
	count := 0
	for k := range keywordMap {
		if strings.Contains(lower, k) {
			count++
		}
	}
	return count
}

func extractTraits(prompt string) []string {
	lower := strings.ToLower(prompt)
	traitMap := map[string]string{
		"fast": "Swift", "hız": "Swift", "accurate": "Precise", "doğru": "Precise",
		"creative": "Creative", "yaratıcı": "Creative", "detail": "Detail-Oriented",
		"systematic": "Systematic", "analytic": "Analytical", "friendly": "Friendly",
	}
	traits := []string{}
	for keyword, trait := range traitMap {
		if strings.Contains(lower, keyword) {
			traits = append(traits, trait)
		}
	}
	if len(traits) == 0 {
		traits = []string{"Versatile"}
	}
	return traits
}

func addVariance(stats map[string]int) map[string]int {
	result := make(map[string]int)
	for k, v := range stats {
		variance := rand.Intn(11) - 5
		val := v + variance
		if val < 1 {
			val = 1
		} else if val > 100 {
			val = 100
		}
		result[k] = val
	}
	return result
}
