package aipipeline

import (
	"encoding/base64"
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

// GenerateImageWithFallback generates an avatar image via Imagen (Gemini),
// then removes the background using the pure-Go BgRemover.
// Returns (base64-encoded image, format) or ("", "") on failure.
func (p *PipelineService) GenerateImageWithFallback(profile *AgentProfile, imagePrompt, charType string) (string, string) {
	sanitized := sanitizeProfile(*profile)

	img, err := p.Gemini.GenerateAvatarImage(&sanitized)
	if err != nil {
		log.Printf("[Avatar] Imagen failed: %v", err)
		return "", ""
	}
	if img == "" {
		log.Printf("[Avatar] Imagen returned empty image (type=%s)", charType)
		return "", ""
	}

	log.Printf("[Avatar] Imagen generated image (type=%s)", charType)

	// Remove background using pure-Go BgRemover
	if p.BgRemover != nil {
		transparentBytes, format := p.BgRemover.RemoveBackground(img)
		if len(transparentBytes) > 0 {
			log.Printf("[Avatar] Background removed (format=%s, type=%s)", format, charType)
			return base64.StdEncoding.EncodeToString(transparentBytes), format
		}
		log.Printf("[Avatar] BgRemover returned empty result, using original image (type=%s)", charType)
	}

	return img, "png"
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
			"a tall pointed hat with silver star embroidery and glowing runic band",
			"layered indigo robes visible at the shoulders with silver thread runes along the collar",
			"orbiting arcane sigils and floating spell pages with glowing purple text swirling around the head",
			"a pulsing amethyst crystal that floats behind the head like a halo, casting violet light",
			"Mysterious and contemplative",
		},
		"strategist": {
			"Deep Crimson", "Burnished Gold", "Red",
			"a steel crowned helm with a crimson plume and golden laurel wreath engraving",
			"polished plate armor pauldrons beneath a crimson commander's surcoat with golden lion crest at the collar",
			"floating tactical map fragments and glowing war strategy symbols orbiting the shoulders",
			"a golden commander's medallion that hovers near the right shoulder, pulsing with red light",
			"Fierce and resolute",
		},
		"oracle": {
			"Amber", "Deep Teal", "Golden",
			"a silk headwrap with a luminous third-eye gemstone set in the center of the forehead",
			"flowing saffron and teal robes with celestial patterns woven into the collar and shoulders",
			"floating constellation charts, spinning astral rings, and tiny orbiting star-lights around the head",
			"a brass astrolabe that hovers beside the ear, its rings slowly rotating and glowing golden",
			"Serene and all-knowing",
		},
		"guardian": {
			"Steel Blue", "Iron Grey", "Ice Blue",
			"a full steel helm with raised visor revealing vigilant ice-blue glowing eyes",
			"heavy ornate plate armor with chainmail visible at the neck and a blue heraldic tabard clasp",
			"protective ward runes etched in light floating in a slow orbit around the helmet and shoulders",
			"a stone gargoyle perched on one massive shoulder pauldron, eyes faintly glowing blue",
			"Steadfast and unyielding",
		},
		"artisan": {
			"Warm Sienna", "Teal", "Warm Copper",
			"a soft beret tilted to one side, flecked with dried paint and a tiny enchanted brush tucked in",
			"a fine linen tunic collar beneath a well-worn leather apron strap stained with magical pigments",
			"tiny enchanted paint droplets and color swirls floating and dancing in the air around the head",
			"a set of ornate miniature chisels and a glowing paintbrush orbiting near the shoulder",
			"Inspired and passionate",
		},
		"bard": {
			"Emerald Green", "Cream", "Golden Yellow",
			"a wide-brimmed feathered hat with a jaunty emerald plume and golden hatband",
			"a velvet doublet collar over a billowing white shirt with an embroidered green cloak clasp at the throat",
			"shimmering golden musical notes drifting visibly through the air and tiny sound-wave ripples of light",
			"an ornate lute neck and tuning pegs visible rising behind the shoulder, strings softly glowing",
			"Cheerful and silver-tongued",
		},
		"scholar": {
			"Warm Brown", "Parchment Beige", "Amber",
			"round brass spectacles perched on a lined and thoughtful face, lenses faintly glowing with knowledge",
			"a brown monastic robe hood draped at the shoulders with ink-stained collar and scroll-case clips",
			"floating open books with luminous text, drifting quill pens, and small enchanted candle flames around the head",
			"an ancient leather-bound tome that hovers open near the shoulder, pages turning by themselves with glowing marginalia",
			"Calm and deeply curious",
		},
		"merchant": {
			"Rich Gold", "Navy Blue", "Orange",
			"a fine velvet cap with a jeweled brooch and a peacock feather, shrewd calculating eyes",
			"a gold-trimmed brocade doublet collar with a heavy jeweled chain of office across the shoulders",
			"floating golden coins, tiny spinning gems, and glowing trade route maps orbiting around the head",
			"a trained raven perched on the shoulder clutching a tiny sealed letter with a wax seal, eyes gleaming",
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
