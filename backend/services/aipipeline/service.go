package aipipeline

import (
	"log"
)

// PipelineService orchestrates AI inference, image generation, and scoring.
// It is the main entry point used by the handler layer.
type PipelineService struct {
	Gemini    *GeminiService
	Claude    *AIService
	Score     *ScoreService
	BgRemover *BgRemover
}

// NewPipelineService creates an orchestrator with all AI sub-services.
func NewPipelineService(gemini *GeminiService, claude *AIService,
	score *ScoreService, bgRemover *BgRemover) *PipelineService {
	return &PipelineService{
		Gemini:    gemini,
		Claude:    claude,
		Score:     score,
		BgRemover: bgRemover,
	}
}

// GenerateImageWithFallback generates an avatar image via Imagen (Gemini).
// Returns base64-encoded image or "" on failure.
func (p *PipelineService) GenerateImageWithFallback(profile *AgentProfile, imagePrompt, charType string) string {
	sanitized := sanitizeProfile(*profile)

	img, err := p.Gemini.GenerateAvatarImage(&sanitized)
	if err != nil {
		log.Printf("[Avatar] Imagen failed: %v", err)
		return ""
	}
	if img == "" {
		log.Printf("[Avatar] Imagen returned empty image (type=%s)", charType)
		return ""
	}

	log.Printf("[Avatar] Imagen generated image (type=%s)", charType)
	return img
}

// BuildFallbackProfile creates a sensible AgentProfile when the LLM call fails.
func BuildFallbackProfile(concept, charType string) *AgentProfile {
	type defaults struct {
		primary, secondary, glow string
		headwear, outfit         string
		uniqueFeature, heldItem  string
		mood                     string
	}
	d := map[string]defaults{
		"wizard": {
			"Deep Purple", "Midnight Blue", "Violet",
			"a tall pointed hat with silver star embroidery",
			"layered indigo robes with silver thread runes along the hem",
			"faint arcane symbols orbiting slowly around the shoulders",
			"a gnarled oak staff crowned with a pulsing amethyst crystal",
			"Mysterious and contemplative",
		},
		"strategist": {
			"Deep Crimson", "Burnished Gold", "Red",
			"a steel crowned helm with a crimson plume",
			"battle-worn plate armor beneath a crimson commander's surcoat with a golden lion crest",
			"a tattered war banner fluttering behind in an unseen wind",
			"a broadsword with a lion-head pommel, point resting on the ground",
			"Fierce and resolute",
		},
		"oracle": {
			"Amber", "Deep Teal", "Golden",
			"a silk headwrap with a third-eye gemstone set in the center of the forehead",
			"flowing saffron and teal robes with celestial patterns woven into the fabric",
			"floating constellation charts and star maps orbiting overhead",
			"a brass astrolabe in one hand and a rolled star chart in the other",
			"Serene and all-knowing",
		},
		"guardian": {
			"Steel Blue", "Iron Grey", "Ice Blue",
			"a full steel helm with a raised visor revealing vigilant eyes",
			"heavy plate armor with chainmail underneath and a blue heraldic tabard",
			"a loyal stone gargoyle perched on one massive shoulder pauldron",
			"a tall tower shield bearing a fortress emblem and a flanged mace",
			"Steadfast and unyielding",
		},
		"artisan": {
			"Warm Sienna", "Teal", "Warm Copper",
			"a soft beret tilted to one side, flecked with dried paint",
			"a fine linen tunic beneath a well-worn leather apron stained with pigments",
			"tiny enchanted paint droplets floating and swirling around the hands",
			"a set of ornate woodcarving chisels and a half-finished miniature sculpture",
			"Inspired and passionate",
		},
		"bard": {
			"Emerald Green", "Cream", "Golden Yellow",
			"a wide-brimmed feathered hat with a jaunty emerald plume",
			"a velvet doublet over a billowing white shirt with an embroidered green travelling cloak",
			"shimmering musical notes drifting visibly through the air",
			"an ornate lute with mother-of-pearl inlay across the neck",
			"Cheerful and silver-tongued",
		},
		"scholar": {
			"Warm Brown", "Parchment Beige", "Amber",
			"round brass spectacles perched on a lined and thoughtful face",
			"a brown monastic robe with ink-stained sleeves and a rope belt hung with scroll cases",
			"a small enchanted candle flame hovering above one shoulder casting warm light",
			"an ancient leather-bound tome open to illuminated pages with glowing marginalia",
			"Calm and deeply curious",
		},
		"merchant": {
			"Rich Gold", "Navy Blue", "Orange",
			"a fine velvet cap with a jeweled brooch and a peacock feather",
			"a gold-trimmed brocade doublet with a heavy coin purse on the belt",
			"a trained raven perched on the shoulder clutching a tiny sealed letter",
			"a set of brass weighing scales balanced in one hand, the other gesturing persuasively",
			"Shrewd and charismatic",
		},
	}
	def, ok := d[charType]
	if !ok {
		def = d["wizard"]
	}
	return &AgentProfile{
		Name:            concept,
		Mood:            def.mood,
		RolePurpose:     "A medieval keeper of knowledge and craft, serving those who seek expert guidance in their domain.",
		PrimaryColor:    def.primary,
		SecondaryColor:  def.secondary,
		TabletGlowColor: def.glow,
		Characteristics: []string{def.headwear, def.outfit, def.uniqueFeature, def.heldItem},
	}
}

// Chat tries Gemini first, falls back to Claude.
func (p *PipelineService) Chat(systemPrompt, userMessage string) (string, error) {
	if resp, err := p.Gemini.Chat(systemPrompt, userMessage); err == nil {
		return resp, nil
	}
	return p.Claude.Chat(systemPrompt, userMessage)
}
