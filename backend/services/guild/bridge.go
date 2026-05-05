package guild

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// BridgeService converts a stored Guild Master suggestion into a Mission
// or Legend Workflow draft so the user can hop from "here's the plan" to
// "let's run it" with one click. The translation is deliberately
// lossless on the source side — failure to bridge never mutates the
// session, only writes a new row to the target table.
type BridgeService struct {
	sessionSvc *SessionService
}

// NewBridgeService wires the session service the bridge needs to read
// suggestion data. Pass the same SessionService instance the rest of
// the handler uses so DB lookups go through one code path.
func NewBridgeService(sessionSvc *SessionService) *BridgeService {
	return &BridgeService{sessionSvc: sessionSvc}
}

// MissionDraftResult is the response payload for /to-mission. Returns
// the freshly-created mission so the frontend can open it directly.
type MissionDraftResult struct {
	Mission *models.UserMission `json:"mission"`
	Source  string              `json:"source"`
}

// LegendDraftResult is the response payload for /to-legend.
type LegendDraftResult struct {
	WorkflowID   string `json:"workflow_id"`
	WorkflowName string `json:"workflow_name"`
	NodeCount    int    `json:"node_count"`
	EdgeCount    int    `json:"edge_count"`
	Source       string `json:"source"`
}

// ToMission seeds a new UserMission from the session's stored suggestion.
// The mission's prompt is composed from Goal + Plan steps + Success
// Criteria so the user can invoke it later via #slug expansion. Title
// falls back to the suggestion's SuggestedName.
//
// Errors: ErrSessionNotFound when the session is missing for the wallet,
// "no suggestion to bridge" when ToMission is called before any
// SuggestGuild result has been stored on the session.
func (b *BridgeService) ToMission(wallet string, sessionID uint) (*MissionDraftResult, error) {
	session, err := b.sessionSvc.GetSession(wallet, sessionID)
	if err != nil {
		return nil, err
	}
	if session.Suggestion == nil {
		return nil, errors.New("no suggestion to bridge — run /suggest first")
	}
	prompt := buildMissionPrompt(session.Suggestion, session.Problem)
	if strings.TrimSpace(prompt) == "" {
		return nil, errors.New("suggestion has no goal/plan/success_criteria to bridge")
	}
	title := strings.TrimSpace(session.Suggestion.SuggestedName)
	if title == "" {
		title = deriveTitle(session.Problem)
	}
	if title == "" {
		title = "Guild Master Mission"
	}
	if len(title) > 120 {
		title = title[:120]
	}

	mission := &models.UserMission{
		UserWallet: strings.ToLower(wallet),
		ClientID:   fmt.Sprintf("gm-%d-%d", sessionID, time.Now().UnixMilli()),
		Title:      title,
		Slug:       slugify(title),
		Prompt:     prompt,
		CreatedAt:  time.Now(),
	}
	if err := database.DB.Create(mission).Error; err != nil {
		return nil, fmt.Errorf("save mission: %w", err)
	}
	// v3.11.4: KPI funnel signal — bridge accepts the suggestion.
	recordGMActivity(wallet, GMActBridgeMission, mission.ID, sessionID)
	return &MissionDraftResult{
		Mission: mission,
		Source:  fmt.Sprintf("guildmaster:%d", sessionID),
	}, nil
}

// ToLegend seeds a new UserLegendWorkflow from the session's suggestion.
// Layout: a single START node fanning out to one agent node per
// MatchingAgent, all converging on a single END node. This is the
// minimal valid DAG; the user can rewire it inside Legend afterwards.
//
// Same error contract as ToMission.
func (b *BridgeService) ToLegend(wallet string, sessionID uint) (*LegendDraftResult, error) {
	session, err := b.sessionSvc.GetSession(wallet, sessionID)
	if err != nil {
		return nil, err
	}
	if session.Suggestion == nil {
		return nil, errors.New("no suggestion to bridge — run /suggest first")
	}
	if len(session.Suggestion.MatchingAgents) == 0 {
		return nil, errors.New("suggestion has no matching agents to bridge")
	}

	nodes, edges := buildWorkflowGraph(session.Suggestion)
	nodesJSON, err := json.Marshal(nodes)
	if err != nil {
		return nil, fmt.Errorf("encode nodes: %w", err)
	}
	edgesJSON, err := json.Marshal(edges)
	if err != nil {
		return nil, fmt.Errorf("encode edges: %w", err)
	}

	clientID := fmt.Sprintf("gm-%d-%d", sessionID, time.Now().UnixMilli())
	name := strings.TrimSpace(session.Suggestion.SuggestedName)
	if name == "" {
		name = "Guild Master Workflow"
	}
	if len(name) > 120 {
		name = name[:120]
	}

	wf := &models.UserLegendWorkflow{
		UserWallet: strings.ToLower(wallet),
		ClientID:   clientID,
		Name:       name,
		NodesJSON:  string(nodesJSON),
		EdgesJSON:  string(edgesJSON),
	}
	if err := database.DB.Create(wf).Error; err != nil {
		return nil, fmt.Errorf("save workflow: %w", err)
	}
	// v3.11.4: KPI funnel signal — Legend bridge accepts the suggestion.
	recordGMActivity(wallet, GMActBridgeLegend, wf.ID, sessionID)
	return &LegendDraftResult{
		WorkflowID:   clientID,
		WorkflowName: name,
		NodeCount:    len(nodes),
		EdgeCount:    len(edges),
		Source:       fmt.Sprintf("guildmaster:%d", sessionID),
	}, nil
}

// buildMissionPrompt composes a single block of text combining goal,
// numbered plan steps, and success criteria. Falls back gracefully when
// any section is missing — at least one of {Goal, Plan, SuccessCriteria}
// must be non-empty for the bridge to succeed.
func buildMissionPrompt(s *GuildSuggestion, problem string) string {
	var b strings.Builder
	if s.Goal != "" {
		b.WriteString("## Goal\n")
		b.WriteString(s.Goal)
		b.WriteString("\n\n")
	} else if problem != "" {
		b.WriteString("## Goal\n")
		b.WriteString(problem)
		b.WriteString("\n\n")
	}
	if len(s.Plan) > 0 {
		b.WriteString("## Plan\n")
		for _, step := range s.Plan {
			fmt.Fprintf(&b, "%d. **%s** — %s\n", step.Step, step.Title, step.Description)
		}
		b.WriteString("\n")
	}
	if len(s.Owners) > 0 {
		b.WriteString("## Owners\n")
		for _, o := range s.Owners {
			fmt.Fprintf(&b, "- **%s** (%s): %s\n", o.Role, o.Type, o.Responsibility)
		}
		b.WriteString("\n")
	}
	if len(s.Risks) > 0 {
		b.WriteString("## Risks\n")
		for _, r := range s.Risks {
			fmt.Fprintf(&b, "- %s\n", r)
		}
		b.WriteString("\n")
	}
	if len(s.SuccessCriteria) > 0 {
		b.WriteString("## Success criteria\n")
		for _, c := range s.SuccessCriteria {
			fmt.Fprintf(&b, "- %s\n", c)
		}
	}
	return strings.TrimSpace(b.String())
}

// buildWorkflowGraph assembles a fan-out/fan-in DAG: 1 start →
// N agent nodes → 1 end. Coordinates are placed on a horizontal grid
// so the user opens Legend to a non-overlapping layout.
func buildWorkflowGraph(s *GuildSuggestion) (nodes []map[string]any, edges []map[string]any) {
	const (
		gridX = 220.0
		gridY = 130.0
	)
	now := time.Now().UnixMilli()

	startID := fmt.Sprintf("n%d-start", now)
	endID := fmt.Sprintf("n%d-end", now)

	nodes = append(nodes, map[string]any{
		"id":     startID,
		"type":   "start",
		"label":  "START",
		"x":      0.0,
		"y":      gridY * float64(len(s.MatchingAgents)) / 2,
		"ref_id": "",
	})

	for i, m := range s.MatchingAgents {
		nodeID := fmt.Sprintf("n%d-a%d", now, i)
		label := strings.TrimSpace(m.Title)
		if label == "" {
			label = fmt.Sprintf("Agent %d", m.ID)
		}
		nodes = append(nodes, map[string]any{
			"id":     nodeID,
			"type":   "agent",
			"label":  label,
			"x":      gridX,
			"y":      gridY * float64(i),
			"ref_id": fmt.Sprintf("%d", m.ID),
		})
		edges = append(edges,
			map[string]any{
				"id":   fmt.Sprintf("e%d-s-%d", now, i),
				"from": startID,
				"to":   nodeID,
			},
			map[string]any{
				"id":   fmt.Sprintf("e%d-%d-e", now, i),
				"from": nodeID,
				"to":   endID,
			},
		)
	}

	nodes = append(nodes, map[string]any{
		"id":     endID,
		"type":   "end",
		"label":  "END",
		"x":      2 * gridX,
		"y":      gridY * float64(len(s.MatchingAgents)) / 2,
		"ref_id": "",
	})
	return nodes, edges
}

// MissionToLegend seeds a new UserLegendWorkflow from a stored mission.
// Layout is the minimal valid DAG: START → MISSION_AGENT → END (3 nodes,
// 2 edges). The mission's prompt is preserved on the agent node so the
// user can wire model/credits inside Legend without re-typing.
//
// Errors:
//   - gorm.ErrRecordNotFound when the mission is missing for the wallet.
//   - "mission has no prompt to bridge" when the mission's prompt is empty
//     after trim (handler maps to 422).
func (b *BridgeService) MissionToLegend(wallet string, missionID uint) (*LegendDraftResult, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, errors.New("wallet required")
	}
	var m models.UserMission
	if err := database.DB.
		Where("id = ? AND user_wallet = ?", missionID, wallet).
		First(&m).Error; err != nil {
		return nil, err
	}
	if strings.TrimSpace(m.Prompt) == "" {
		return nil, errors.New("mission has no prompt to bridge")
	}

	title := strings.TrimSpace(m.Title)
	if title == "" {
		title = "Mission"
	}
	if len(title) > 120 {
		title = title[:120]
	}

	nodes, edges := buildSingleNodeWorkflow(title, m.Prompt)
	nodesJSON, err := json.Marshal(nodes)
	if err != nil {
		return nil, fmt.Errorf("encode nodes: %w", err)
	}
	edgesJSON, err := json.Marshal(edges)
	if err != nil {
		return nil, fmt.Errorf("encode edges: %w", err)
	}

	clientID := fmt.Sprintf("mission-%d-%d", missionID, time.Now().UnixMilli())
	name := fmt.Sprintf("From mission: %s", title)
	if len(name) > 120 {
		name = name[:120]
	}

	wf := &models.UserLegendWorkflow{
		UserWallet: wallet,
		ClientID:   clientID,
		Name:       name,
		NodesJSON:  string(nodesJSON),
		EdgesJSON:  string(edgesJSON),
	}
	if err := database.DB.Create(wf).Error; err != nil {
		return nil, fmt.Errorf("save workflow: %w", err)
	}
	return &LegendDraftResult{
		WorkflowID:   clientID,
		WorkflowName: name,
		NodeCount:    len(nodes),
		EdgeCount:    len(edges),
		Source:       fmt.Sprintf("mission:%d", missionID),
	}, nil
}

// buildSingleNodeWorkflow assembles the minimal valid Legend DAG:
// START → MISSION_AGENT → END. The middle node carries the mission prompt
// as its label (truncated for visual sanity) and the full prompt in
// `prompt` so the user sees real content the moment Legend opens.
func buildSingleNodeWorkflow(title, prompt string) (nodes []map[string]any, edges []map[string]any) {
	now := time.Now().UnixMilli()
	startID := fmt.Sprintf("n%d-start", now)
	agentID := fmt.Sprintf("n%d-mission", now)
	endID := fmt.Sprintf("n%d-end", now)

	label := title
	if label == "" {
		label = "Mission"
	}
	if len(label) > 60 {
		label = label[:60]
	}

	nodes = []map[string]any{
		{
			"id":     startID,
			"type":   "start",
			"label":  "START",
			"x":      0.0,
			"y":      0.0,
			"ref_id": "",
		},
		{
			"id":     agentID,
			"type":   "agent",
			"label":  label,
			"prompt": prompt,
			"x":      220.0,
			"y":      0.0,
			"ref_id": "",
		},
		{
			"id":     endID,
			"type":   "end",
			"label":  "END",
			"x":      440.0,
			"y":      0.0,
			"ref_id": "",
		},
	}
	edges = []map[string]any{
		{"id": fmt.Sprintf("e%d-s-m", now), "from": startID, "to": agentID},
		{"id": fmt.Sprintf("e%d-m-e", now), "from": agentID, "to": endID},
	}
	return nodes, edges
}

// slugify lowercases the title and collapses runs of non-alphanumerics
// into single hyphens so the result satisfies the Mission slug regex
// (^[a-z0-9][a-z0-9_-]*$). Strips leading/trailing hyphens. Falls back
// to a timestamp if the input distils down to nothing.
func slugify(in string) string {
	in = strings.ToLower(strings.TrimSpace(in))
	var b strings.Builder
	dash := false
	for _, r := range in {
		switch {
		case (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9'):
			b.WriteRune(r)
			dash = false
		case r == '-':
			b.WriteRune('-')
			dash = true
		case r == '_':
			// Underscore is allowed by the Mission slug regex
			// (^[a-z0-9][a-z0-9_-]*$). Preserve so user-supplied
			// names round-trip without surprise canonicalisation.
			b.WriteRune('_')
			dash = false
		default:
			if !dash && b.Len() > 0 {
				b.WriteByte('-')
				dash = true
			}
		}
	}
	out := strings.Trim(b.String(), "-_")
	if out == "" {
		out = fmt.Sprintf("gm-%d", time.Now().UnixMilli())
	}
	if len(out) > 80 {
		out = strings.TrimRight(out[:80], "-")
	}
	// Slug must start with [a-z0-9]; if leading char is somehow not, prefix.
	if first := out[0]; !((first >= 'a' && first <= 'z') || (first >= '0' && first <= '9')) {
		out = "gm-" + out
	}
	return out
}
