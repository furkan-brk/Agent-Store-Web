package gamification

// SynergyBonus represents a guild synergy bonus.
type SynergyBonus struct {
	Name  string         `json:"name"`
	Bonus map[string]int `json:"bonus"`
}

// CalculateGuildSynergy calculates synergy bonuses for a guild and returns active bonuses + combined stat boost.
func CalculateGuildSynergy(types []string) ([]SynergyBonus, map[string]int) {
	bonuses := []SynergyBonus{}
	combined := map[string]int{}

	typeSet := map[string]bool{}
	for _, t := range types {
		typeSet[t] = true
	}

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

	if len(typeSet) >= 4 {
		b := SynergyBonus{Name: "Legendary Assembly", Bonus: map[string]int{"intelligence": 10, "power": 10, "speed": 10, "creativity": 10, "defense": 10}}
		bonuses = append(bonuses, b)
		addBonus(combined, b.Bonus)
	}

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
