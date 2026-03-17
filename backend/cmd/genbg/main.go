package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Background defines a background scene with tags for agent matching.
type Background struct {
	ID     string   `json:"id"`
	Name   string   `json:"name"`
	Tags   []string `json:"tags"`
	Prompt string   `json:"prompt"`
}

var backgrounds = []Background{
	{ID: "arcane_library", Name: "Arcane Library", Tags: []string{"backend", "wizard", "scholar", "research"}, Prompt: "Medieval fantasy arcane library interior, towering bookshelves reaching into shadow, floating magical tomes with glowing pages, warm candlelight, dust motes in golden light beams, ancient stone arches, mystical atmosphere, no people, no characters, slightly soft dreamy focus, warm parchment tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "wizard_tower", Name: "Wizard Tower", Tags: []string{"backend", "wizard", "general"}, Prompt: "Medieval fantasy wizard tower interior, spiral stone staircase, glowing crystal orbs on shelves, alchemical apparatus, starlit window revealing night sky, purple and blue magical energy wisps, ancient scrolls scattered on oak desk, no people, no characters, atmospheric soft focus, warm tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "throne_room", Name: "Throne Room", Tags: []string{"strategist", "business", "general"}, Prompt: "Medieval fantasy grand throne room, ornate golden throne on raised dais, crimson banners hanging from stone pillars, stained glass windows casting colored light, polished marble floor, braziers with warm fire, regal and commanding atmosphere, no people, no characters, slightly blurred soft focus, warm golden tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "war_tent", Name: "War Command Tent", Tags: []string{"strategist", "general"}, Prompt: "Medieval fantasy war command tent interior, large tactical map spread on wooden table, miniature army figurines, oil lanterns casting warm light, armor stands, sword rack, canvas tent walls, battle plans pinned to board, military atmosphere, no people, no characters, soft focus, warm amber tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "observatory", Name: "Celestial Observatory", Tags: []string{"oracle", "data", "research"}, Prompt: "Medieval fantasy celestial observatory tower, massive brass astrolabe, star charts on walls, telescope pointed at starlit sky through domed opening, floating constellation maps, crystal spheres reflecting starlight, mystical cosmic atmosphere, no people, no characters, soft dreamy focus, deep blue and gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "crystal_cave", Name: "Crystal Cavern", Tags: []string{"oracle", "data"}, Prompt: "Medieval fantasy underground crystal cavern, massive glowing crystals in amber and teal, underground river reflecting crystal light, stalactites with bioluminescent moss, natural stone formations, ethereal mysterious atmosphere, no people, no characters, soft atmospheric focus, warm amber and cool teal tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "fortress_wall", Name: "Fortress Battlements", Tags: []string{"guardian", "security", "general"}, Prompt: "Medieval fantasy fortress battlements at sunset, massive stone walls with crenellations, iron-reinforced gate visible below, watchtower with signal fire, distant mountains, heavy defensive architecture, shields and spears mounted on walls, strong protective atmosphere, no people, no characters, soft golden hour light, warm stone tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "castle_gate", Name: "Castle Gatehouse", Tags: []string{"guardian", "security"}, Prompt: "Medieval fantasy castle gatehouse interior, massive iron portcullis, torch-lit stone corridors, arrow slits in thick walls, heavy oak doors with iron bands, guard room with weapon racks, chains and pulleys for drawbridge mechanism, defensive stronghold atmosphere, no people, no characters, soft torchlight focus, warm grey and amber tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "artisan_workshop", Name: "Artisan Workshop", Tags: []string{"artisan", "frontend", "creative"}, Prompt: "Medieval fantasy artisan workshop, woodcarving tools on workbench, half-finished sculptures, colorful paint pots, easel with canvas, stained glass pieces, natural light from large arched window, creative clutter of materials, warm inviting atmosphere, no people, no characters, soft warm focus, rich sienna and teal tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "gallery_hall", Name: "Royal Gallery", Tags: []string{"artisan", "frontend"}, Prompt: "Medieval fantasy royal art gallery, ornate gilded frames on stone walls, tapestries depicting mythical scenes, marble pedestals with sculptures, polished herringbone floor, skylights casting natural light, refined elegant atmosphere, no people, no characters, soft dreamy focus, warm cream and gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "tavern_hearth", Name: "Tavern Hearth", Tags: []string{"bard", "creative", "general"}, Prompt: "Medieval fantasy cozy tavern interior, large stone fireplace with roaring fire, wooden beams on ceiling, ale mugs on oak bar counter, lute leaning against chair, warm orange candlelight, worn wooden floor, comfortable welcoming atmosphere, no people, no characters, soft warm focus, rich amber and brown tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "forest_clearing", Name: "Enchanted Forest Clearing", Tags: []string{"bard", "creative"}, Prompt: "Medieval fantasy enchanted forest clearing at twilight, ancient oak trees with firefly lights, moss-covered stones arranged in circle, wild flowers glowing softly, small stream reflecting moonlight, magical woodland atmosphere, no people, no characters, soft ethereal focus, emerald green and warm gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "monastery", Name: "Monastery Scriptorium", Tags: []string{"scholar", "research"}, Prompt: "Medieval fantasy monastery scriptorium, rows of slanted writing desks, illuminated manuscripts with gold leaf, inkwells and quill pens, tall narrow windows with plain glass, stone arched ceiling, quiet contemplative atmosphere, candles providing warm focused light, no people, no characters, soft warm focus, parchment beige and brown tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "ancient_archive", Name: "Ancient Archive", Tags: []string{"scholar", "research", "data"}, Prompt: "Medieval fantasy underground archive vault, endless rows of scroll shelves carved into rock, floating magical index lights, ancient stone catalog drawers, protective ward runes on doorframe, reverent quiet atmosphere of stored knowledge, no people, no characters, soft amber focus, warm brown and gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "market_square", Name: "Market Square", Tags: []string{"merchant", "business"}, Prompt: "Medieval fantasy bustling market square at golden hour, colorful merchant stalls with awnings, exotic goods displayed on tables, cobblestone ground, fountain in center, guild hall building in background, festive trading atmosphere, no people, no characters, soft golden light, warm rich tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "trading_port", Name: "Trading Harbor", Tags: []string{"merchant", "business"}, Prompt: "Medieval fantasy trading harbor, wooden sailing ships docked at stone pier, cargo crates and barrels, warehouse buildings, calm sea reflecting sunset, lighthouse in distance, prosperous maritime atmosphere, no people, no characters, soft sunset focus, warm orange and navy tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "alchemy_lab", Name: "Alchemist Laboratory", Tags: []string{"wizard", "oracle", "backend", "data"}, Prompt: "Medieval fantasy alchemist laboratory, bubbling glass flasks and retorts, colorful liquid potions, herb bundles hanging from ceiling, mortar and pestle, flame under copper distillation apparatus, mysterious smoke wisps, experimental atmosphere, no people, no characters, soft warm focus, emerald and amber tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "training_grounds", Name: "Knight Training Grounds", Tags: []string{"strategist", "guardian", "general"}, Prompt: "Medieval fantasy knight training grounds at dawn, wooden practice dummies, weapon racks with swords and shields, sand arena with fence, stone castle wall in background, morning mist, disciplined martial atmosphere, no people, no characters, soft dawn light focus, warm grey and gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "royal_court", Name: "Royal Court Chamber", Tags: []string{"strategist", "merchant", "business"}, Prompt: "Medieval fantasy royal court chamber, long polished conference table with maps, ornate high-backed chairs, coat of arms tapestries, chandelier with many candles, tall arched windows with heavy drapes, political power atmosphere, no people, no characters, soft candlelight focus, rich burgundy and gold tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
	{ID: "enchanted_garden", Name: "Enchanted Garden", Tags: []string{"artisan", "bard", "creative", "general"}, Prompt: "Medieval fantasy enchanted castle garden, stone pathways between magical flower beds, ornamental fountain with crystal-clear water, ivy-covered archway, perfectly trimmed hedges, butterflies and small birds, peaceful serene atmosphere, no people, no characters, soft dreamy focus, lush green and pastel tones, wide landscape composition. No text, letters, numbers, words, or symbols anywhere."},
}

func main() {
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Fatal("GEMINI_API_KEY env required")
	}

	outDir := os.Args[1]
	if outDir == "" {
		outDir = "../../agent_store/assets/backgrounds"
	}
	os.MkdirAll(outDir, 0755)

	// Generate backgrounds with concurrency limit of 3
	sem := make(chan struct{}, 3)
	var wg sync.WaitGroup

	for i, bg := range backgrounds {
		wg.Add(1)
		go func(idx int, bg Background) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			outPath := filepath.Join(outDir, bg.ID+".png")
			if _, err := os.Stat(outPath); err == nil {
				fmt.Printf("[%d/20] SKIP %s (already exists)\n", idx+1, bg.ID)
				return
			}

			fmt.Printf("[%d/20] Generating %s...\n", idx+1, bg.ID)
			start := time.Now()

			imgBase64, err := callImagen(apiKey, bg.Prompt)
			if err != nil {
				log.Printf("[%d/20] FAILED %s: %v (%.1fs)", idx+1, bg.ID, err, time.Since(start).Seconds())
				return
			}

			imgBytes, err := base64.StdEncoding.DecodeString(imgBase64)
			if err != nil {
				log.Printf("[%d/20] DECODE FAILED %s: %v", idx+1, bg.ID, err)
				return
			}

			if err := os.WriteFile(outPath, imgBytes, 0644); err != nil {
				log.Printf("[%d/20] WRITE FAILED %s: %v", idx+1, bg.ID, err)
				return
			}

			fmt.Printf("[%d/20] OK %s (%.1fs, %d KB)\n", idx+1, bg.ID, time.Since(start).Seconds(), len(imgBytes)/1024)
		}(i, bg)
	}

	wg.Wait()

	// Write metadata JSON
	metaPath := filepath.Join(outDir, "backgrounds.json")
	meta, _ := json.MarshalIndent(backgrounds, "", "  ")
	os.WriteFile(metaPath, meta, 0644)

	fmt.Println("\nBackground generation complete!")
	fmt.Printf("Metadata written to %s\n", metaPath)
}

func callImagen(apiKey, prompt string) (string, error) {
	url := "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-fast-generate-001:predict"

	reqBody := map[string]interface{}{
		"instances":  []map[string]interface{}{{"prompt": prompt}},
		"parameters": map[string]interface{}{"sampleCount": 1, "aspectRatio": "16:9", "personGeneration": "DONT_ALLOW"},
	}

	body, _ := json.Marshal(reqBody)
	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", apiKey)
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("imagen %d: %s", resp.StatusCode, string(respBody[:min(200, len(respBody))]))
	}

	var imgResp struct {
		Predictions []struct {
			BytesBase64Encoded string `json:"bytesBase64Encoded"`
		} `json:"predictions"`
	}
	json.Unmarshal(respBody, &imgResp)
	if len(imgResp.Predictions) == 0 {
		return "", fmt.Errorf("no predictions")
	}
	return imgResp.Predictions[0].BytesBase64Encoded, nil
}
