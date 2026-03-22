package aipipeline

import (
	"encoding/json"
	"math/rand"
	"strings"

	"github.com/agentstore/backend/pkg/models"
)

// CharacterResult holds the gamification stats computed for an agent.
type CharacterResult struct {
	Type     string            `json:"type"`
	Subclass string            `json:"subclass"`
	Name     string            `json:"name"`
	Rarity   string            `json:"rarity"`
	Colors   map[string]string `json:"colors"`
	Stats    map[string]int    `json:"stats"`
	Traits   []string          `json:"traits"`
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
	// ── Wizard (Backend / Code / DevOps) ──
	"backend": "wizard", "golang": "wizard", "python": "wizard", "api": "wizard",
	"database": "wizard", "server": "wizard", "kod": "wizard", "code": "wizard",
	"developer": "wizard", "sql": "wizard", "java": "wizard", "programmer": "wizard",
	"rust": "wizard", "typescript": "wizard", "javascript": "wizard", "node": "wizard",
	"docker": "wizard", "kubernetes": "wizard", "microservice": "wizard", "cli": "wizard",
	"script": "wizard", "algorithm": "wizard", "compiler": "wizard", "debug": "wizard",
	"refactor": "wizard", "git": "wizard", "deploy": "wizard", "terraform": "wizard",
	"lambda": "wizard", "redis": "wizard", "mongodb": "wizard", "graphql": "wizard",
	"grpc": "wizard", "geliştirici": "wizard", "yazılım": "wizard", "programlama": "wizard",

	// ── Strategist (Planning / PM / Leadership) ──
	"plan": "strategist", "strategy": "strategist", "project": "strategist",
	"manager": "strategist", "roadmap": "strategist", "agile": "strategist",
	"scrum": "strategist", "task": "strategist", "stratejist": "strategist",
	"lead": "strategist", "coordinate": "strategist", "prioritize": "strategist",
	"deadline": "strategist", "sprint": "strategist", "okr": "strategist",
	"milestone": "strategist", "gantt": "strategist", "kanban": "strategist",
	"delegate": "strategist", "decision": "strategist", "stakeholder": "strategist",
	"resource": "strategist", "timeline": "strategist", "objective": "strategist",
	"planlama": "strategist", "yönetim": "strategist", "hedef": "strategist",
	"organize": "strategist", "schedule": "strategist", "workflow": "strategist",

	// ── Oracle (Data / Analytics / AI/ML) ──
	"data": "oracle", "analytics": "oracle", "analiz": "oracle", "insight": "oracle",
	"statistics": "oracle", "ml": "oracle", "machine learning": "oracle",
	"artificial intelligence": "oracle", "neural": "oracle", "deep learning": "oracle",
	"dataset": "oracle", "visualization": "oracle", "prediction": "oracle",
	"tableau": "oracle", "powerbi": "oracle", "pandas": "oracle", "numpy": "oracle",
	"tensorflow": "oracle", "pytorch": "oracle", "regression": "oracle",
	"classification": "oracle", "clustering": "oracle", "nlp": "oracle",
	"llm": "oracle", "embedding": "oracle", "vector": "oracle", "rag": "oracle",
	"veri": "oracle", "tahmin": "oracle", "model": "oracle", "forecast": "oracle",
	"metric": "oracle", "dashboard": "oracle", "bigquery": "oracle",

	// ── Guardian (Security / Infrastructure / Reliability) ──
	"security": "guardian", "güvenlik": "guardian", "firewall": "guardian",
	"pentest": "guardian", "infra": "guardian", "hacker": "guardian",
	"encrypt": "guardian", "auth": "guardian", "vulnerability": "guardian",
	"devops": "guardian", "cloud": "guardian", "aws": "guardian", "azure": "guardian",
	"monitoring": "guardian", "backup": "guardian", "ssl": "guardian", "tls": "guardian",
	"oauth": "guardian", "jwt": "guardian", "penetration": "guardian",
	"compliance": "guardian", "audit": "guardian", "sre": "guardian",
	"incident": "guardian", "disaster recovery": "guardian",
	"antivirus": "guardian", "malware": "guardian", "phishing": "guardian",
	"koruma": "guardian", "şifre": "guardian", "saldırı": "guardian",
	"vpn": "guardian", "proxy": "guardian", "sandbox": "guardian",

	// ── Artisan (Frontend / Design / UX) ──
	"frontend": "artisan", "ui": "artisan", "ux": "artisan", "design": "artisan",
	"flutter": "artisan", "react": "artisan", "css": "artisan",
	"figma": "artisan", "prototype": "artisan", "responsive": "artisan",
	"layout": "artisan", "animation": "artisan", "tailwind": "artisan",
	"component": "artisan", "widget": "artisan", "sketch": "artisan",
	"wireframe": "artisan", "pixel": "artisan", "color scheme": "artisan",
	"typography": "artisan", "icon": "artisan", "illustration": "artisan",
	"accessibility": "artisan", "mobile app": "artisan", "swiftui": "artisan",
	"tasarım": "artisan", "arayüz": "artisan", "görsel": "artisan",
	"html": "artisan", "sass": "artisan", "bootstrap": "artisan",

	// ── Bard (Creative / Writing / Communication) ──
	"write": "bard", "yaz": "bard", "story": "bard", "creative": "bard",
	"content": "bard", "blog": "bard", "copy": "bard",
	"poem": "bard", "translate": "bard", "email": "bard", "summarize": "bard",
	"tone": "bard", "chat": "bard", "conversation": "bard", "dialogue": "bard",
	"screenplay": "bard", "novel": "bard", "fiction": "bard", "essay": "bard",
	"slogan": "bard", "headline": "bard", "caption": "bard", "lyric": "bard",
	"speech": "bard", "presentation": "bard", "pitch": "bard",
	"metin": "bard", "hikaye": "bard", "çeviri": "bard", "şiir": "bard",
	"narrative": "bard", "persona": "bard", "roleplay": "bard",
	"letter": "bard", "report": "bard",

	// ── Scholar (Research / Education / Knowledge) ──
	"research": "scholar", "araştır": "scholar", "study": "scholar",
	"academic": "scholar", "science": "scholar", "learn": "scholar",
	"explain": "scholar", "teach": "scholar", "tutor": "scholar",
	"knowledge": "scholar", "history": "scholar", "math": "scholar",
	"physics": "scholar", "chemistry": "scholar", "biology": "scholar",
	"philosophy": "scholar", "literature": "scholar", "encyclopedia": "scholar",
	"thesis": "scholar", "paper": "scholar", "journal": "scholar",
	"lecture": "scholar", "curriculum": "scholar", "exam": "scholar",
	"eğitim": "scholar", "öğren": "scholar", "bilim": "scholar", "ders": "scholar",
	"university": "scholar", "professor": "scholar", "textbook": "scholar",
	"quiz": "scholar", "homework": "scholar",

	// ── Merchant (Business / Finance / Marketing) ──
	"business": "merchant", "sales": "merchant", "marketing": "merchant",
	"growth": "merchant", "revenue": "merchant", "startup": "merchant",
	"finance": "merchant", "ecommerce": "merchant", "pricing": "merchant",
	"customer": "merchant", "roi": "merchant", "brand": "merchant",
	"negotiate": "merchant", "profit": "merchant", "investment": "merchant",
	"stock": "merchant", "crypto": "merchant", "blockchain": "merchant",
	"seo": "merchant", "ads": "merchant", "campaign": "merchant",
	"funnel": "merchant", "conversion": "merchant", "churn": "merchant",
	"retention": "merchant", "b2b": "merchant", "saas": "merchant",
	"ticaret": "merchant", "pazarlama": "merchant", "müşteri": "merchant",
	"gelir": "merchant", "fiyat": "merchant", "satış": "merchant",
}

var subclassKeywords = map[string]map[string][]string{
	"wizard": {
		"archmage":   {"architect", "senior", "system design", "enterprise", "principal", "distributed", "scalable", "microservice", "infrastructure"},
		"sorcerer":   {"fullstack", "versatile", "all", "everything", "general", "polyglot", "multi-language", "jack of all"},
		"hex_master": {"debug", "fix", "bug", "error", "patch", "troubleshoot", "diagnose", "stacktrace", "crash", "memory leak"},
	},
	"strategist": {
		"war_commander": {"scale", "growth", "ambitious", "expand", "aggressive", "vision", "transform", "disrupt", "10x"},
		"tactician":     {"step", "process", "structured", "workflow", "systematic", "checklist", "sop", "procedure", "framework"},
		"diplomat":      {"collaborate", "team", "stakeholder", "align", "negotiate", "consensus", "facilitate", "mediate", "cross-functional"},
	},
	"oracle": {
		"prophet": {"predict", "forecast", "ml", "model", "future", "trend", "time series", "anomaly", "neural network"},
		"analyst": {"metrics", "kpi", "measure", "report", "dashboard", "sql", "query", "aggregate", "cohort"},
		"seer":    {"pattern", "visualization", "chart", "graph", "insight", "heatmap", "correlation", "segment", "funnel"},
	},
	"guardian": {
		"sentinel": {"pentest", "exploit", "hack", "vulnerability", "offensive", "ctf", "red team", "injection", "xss"},
		"warden":   {"uptime", "monitor", "alert", "sre", "reliability", "prometheus", "grafana", "oncall", "latency"},
		"paladin":  {"compliance", "audit", "policy", "gdpr", "governance", "hipaa", "soc2", "regulation", "privacy"},
	},
	"artisan": {
		"sculptor": {"animation", "3d", "motion", "interactive", "canvas", "webgl", "three.js", "particle", "transition"},
		"weaver":   {"component", "design system", "library", "storybook", "reusable", "atomic", "theme", "token"},
		"painter":  {"visual", "aesthetic", "brand", "color", "palette", "gradient", "shadow", "glassmorphism", "illustration"},
	},
	"bard": {
		"storyteller": {"narrative", "essay", "long", "article", "fiction", "worldbuilding", "character arc", "plot", "chapter"},
		"lyricist":    {"headline", "copy", "tagline", "hook", "viral", "slogan", "punchline", "catchy", "snappy"},
		"chronicler":  {"documentation", "guide", "manual", "readme", "wiki", "changelog", "release notes", "faq", "how-to"},
	},
	"scholar": {
		"sage":      {"theory", "thesis", "academic", "paper", "philosophy", "epistemology", "logic", "reasoning", "axiom"},
		"professor": {"teach", "tutorial", "course", "lesson", "explain", "curriculum", "syllabus", "lecture", "student"},
		"librarian": {"organize", "catalog", "archive", "curate", "index", "taxonomy", "tag", "classify", "reference"},
	},
	"merchant": {
		"entrepreneur": {"startup", "mvp", "pivot", "launch", "bootstrapped", "product-market fit", "seed", "venture", "disrupt"},
		"trader":       {"sales", "revenue", "funnel", "conversion", "deal", "pipeline", "quota", "close", "upsell"},
		"ambassador":   {"brand", "community", "viral", "influencer", "partner", "advocacy", "ambassador", "outreach", "engagement"},
	},
}

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

var defaultSubclass = map[string]string{
	"wizard": "archmage", "strategist": "war_commander", "oracle": "prophet",
	"guardian": "sentinel", "artisan": "sculptor", "bard": "storyteller",
	"scholar": "sage", "merchant": "entrepreneur",
}

// allCharacterTypes enumerates every valid character type for random selection.
var allCharacterTypes = []string{
	"wizard", "strategist", "oracle", "guardian",
	"artisan", "bard", "scholar", "merchant",
}

// DetermineCharacterType uses keyword matching to classify a prompt into a character type.
// When no keywords match (bestScore == 0), a random type is selected instead of defaulting to wizard.
func DetermineCharacterType(prompt string) string {
	lower := strings.ToLower(prompt)
	scores := make(map[string]int)
	for keyword, charType := range keywordMap {
		if strings.Contains(lower, keyword) {
			scores[charType]++
		}
	}
	best := ""
	bestScore := 0
	for charType, score := range scores {
		if score > bestScore {
			bestScore = score
			best = charType
		}
	}
	if bestScore == 0 {
		return allCharacterTypes[rand.Intn(len(allCharacterTypes))]
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

// DetermineRarity classifies prompt complexity into a rarity tier.
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

// MergeProfileIntoCharacterData merges an AgentProfile into existing character_data JSON.
func MergeProfileIntoCharacterData(charDataJSON string, profile *AgentProfile) string {
	if profile == nil {
		return charDataJSON
	}
	var data map[string]any
	if err := json.Unmarshal([]byte(charDataJSON), &data); err != nil {
		data = map[string]any{}
	}
	data["profile"] = profile
	result, err := json.Marshal(data)
	if err != nil {
		return charDataJSON
	}
	return string(result)
}

// BuildCharacterData builds the full character_data JSON for an agent.
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
