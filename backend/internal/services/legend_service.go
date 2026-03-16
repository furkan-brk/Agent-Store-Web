package services

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
	"gorm.io/gorm"
)

// LegendService handles legend workflow CRUD, validation, and execution.
type LegendService struct {
	geminiSvc  *GeminiService
	missionSvc *MissionService
}

// NewLegendService creates a new LegendService.
func NewLegendService(geminiSvc *GeminiService, missionSvc *MissionService) *LegendService {
	return &LegendService{geminiSvc: geminiSvc, missionSvc: missionSvc}
}

// SaveLegendWorkflowInput is the request payload for creating or updating a workflow.
type SaveLegendWorkflowInput struct {
	ID        string          `json:"id" binding:"required"`
	Name      string          `json:"name" binding:"required"`
	Nodes     json.RawMessage `json:"nodes" binding:"required"`
	Edges     json.RawMessage `json:"edges" binding:"required"`
	UpdatedAt time.Time       `json:"updated_at"`
}

// LegendWorkflowDTO is the response representation of a workflow.
type LegendWorkflowDTO struct {
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Nodes     json.RawMessage `json:"nodes"`
	Edges     json.RawMessage `json:"edges"`
	UpdatedAt time.Time       `json:"updated_at"`
}

// WorkflowNodeParsed is the internal representation of a workflow node.
type WorkflowNodeParsed struct {
	ID    string  `json:"id"`
	Type  string  `json:"type"`
	Label string  `json:"label"`
	X     float64 `json:"x"`
	Y     float64 `json:"y"`
	RefID string  `json:"ref_id"`
}

// WorkflowEdgeParsed is the internal representation of a workflow edge.
type WorkflowEdgeParsed struct {
	ID   string `json:"id"`
	From string `json:"from"`
	To   string `json:"to"`
}

// NodeExecutionResult holds the outcome of executing a single node.
type NodeExecutionResult struct {
	NodeID     string `json:"node_id"`
	NodeType   string `json:"node_type"`
	NodeLabel  string `json:"node_label"`
	Input      string `json:"input"`
	Output     string `json:"output"`
	AgentID    *uint  `json:"agent_id,omitempty"`
	DurationMs int64  `json:"duration_ms"`
	Error      string `json:"error,omitempty"`
}

// ExecuteWorkflowInput is the request payload for workflow execution.
type ExecuteWorkflowInput struct {
	InputMessage string `json:"input_message" binding:"required"`
}

// ExecutionStatusDTO is the response representation of a workflow execution.
type ExecutionStatusDTO struct {
	ID             uint                  `json:"id"`
	WorkflowID     string                `json:"workflow_id"`
	WorkflowName   string                `json:"workflow_name"`
	Status         string                `json:"status"`
	InputMessage   string                `json:"input_message"`
	FinalOutput    string                `json:"final_output"`
	NodeResults    []NodeExecutionResult `json:"node_results"`
	TotalNodes     int                   `json:"total_nodes"`
	CompletedNodes int                   `json:"completed_nodes"`
	CreditsUsed    int64                 `json:"credits_used"`
	ErrorMessage   string                `json:"error_message,omitempty"`
	StartedAt      time.Time             `json:"started_at"`
	FinishedAt     *time.Time            `json:"finished_at,omitempty"`
}

// ListUserWorkflows returns all workflows for a wallet.
func (s *LegendService) ListUserWorkflows(wallet string) ([]LegendWorkflowDTO, error) {
	var records []models.UserLegendWorkflow
	if err := database.DB.
		Where("user_wallet = ?", strings.ToLower(wallet)).
		Order("updated_at DESC").
		Find(&records).Error; err != nil {
		return nil, err
	}

	result := make([]LegendWorkflowDTO, 0, len(records))
	for _, record := range records {
		nodes := json.RawMessage(record.NodesJSON)
		edges := json.RawMessage(record.EdgesJSON)
		if len(nodes) == 0 {
			nodes = json.RawMessage("[]")
		}
		if len(edges) == 0 {
			edges = json.RawMessage("[]")
		}
		result = append(result, LegendWorkflowDTO{
			ID:        record.ClientID,
			Name:      record.Name,
			Nodes:     nodes,
			Edges:     edges,
			UpdatedAt: record.UpdatedAt,
		})
	}
	return result, nil
}

// SaveUserWorkflow creates or updates a workflow after validation.
func (s *LegendService) SaveUserWorkflow(wallet string, input SaveLegendWorkflowInput) (*LegendWorkflowDTO, error) {
	if err := validateWorkflowInput(input); err != nil {
		return nil, err
	}

	wallet = strings.ToLower(wallet)
	record := &models.UserLegendWorkflow{}
	err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(record).Error
	if err != nil {
		record = &models.UserLegendWorkflow{
			UserWallet: wallet,
			ClientID:   input.ID,
		}
	}
	updatedAt := input.UpdatedAt
	if updatedAt.IsZero() {
		updatedAt = time.Now()
	}
	record.Name = input.Name
	record.NodesJSON = string(input.Nodes)
	record.EdgesJSON = string(input.Edges)
	record.UpdatedAt = updatedAt

	if err := database.DB.Save(record).Error; err != nil {
		return nil, err
	}

	return &LegendWorkflowDTO{
		ID:        record.ClientID,
		Name:      record.Name,
		Nodes:     json.RawMessage(record.NodesJSON),
		Edges:     json.RawMessage(record.EdgesJSON),
		UpdatedAt: record.UpdatedAt,
	}, nil
}

// BatchSyncWorkflows upserts multiple workflows in one request and returns the
// full list of all user workflows from the DB. This replaces N sequential save
// calls during local→remote sync.
func (s *LegendService) BatchSyncWorkflows(wallet string, inputs []SaveLegendWorkflowInput) ([]LegendWorkflowDTO, error) {
	wallet = strings.ToLower(wallet)

	for _, input := range inputs {
		if err := validateWorkflowInput(input); err != nil {
			return nil, fmt.Errorf("invalid workflow %q: %w", input.ID, err)
		}

		record := &models.UserLegendWorkflow{}
		err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(record).Error
		if err != nil {
			record = &models.UserLegendWorkflow{
				UserWallet: wallet,
				ClientID:   input.ID,
			}
		}
		updatedAt := input.UpdatedAt
		if updatedAt.IsZero() {
			updatedAt = time.Now()
		}
		record.Name = input.Name
		record.NodesJSON = string(input.Nodes)
		record.EdgesJSON = string(input.Edges)
		record.UpdatedAt = updatedAt

		if err := database.DB.Save(record).Error; err != nil {
			return nil, fmt.Errorf("failed to save workflow %q: %w", input.ID, err)
		}
	}

	return s.ListUserWorkflows(wallet)
}

// DeleteUserWorkflow removes a workflow by wallet and client ID.
func (s *LegendService) DeleteUserWorkflow(wallet, clientID string) error {
	return database.DB.Where("user_wallet = ? AND client_id = ?", strings.ToLower(wallet), clientID).Delete(&models.UserLegendWorkflow{}).Error
}

// validateWorkflowInput checks basic input constraints.
func validateWorkflowInput(input SaveLegendWorkflowInput) error {
	name := strings.TrimSpace(input.Name)
	if len(name) == 0 || len(name) > 120 {
		return fmt.Errorf("name must be 1-120 characters")
	}
	if !json.Valid(input.Nodes) {
		return fmt.Errorf("nodes must be valid JSON")
	}
	if !json.Valid(input.Edges) {
		return fmt.Errorf("edges must be valid JSON")
	}
	return nil
}

// parseWorkflow deserializes node and edge JSON into typed slices.
func parseWorkflow(nodesJSON, edgesJSON string) ([]WorkflowNodeParsed, []WorkflowEdgeParsed, error) {
	var nodes []WorkflowNodeParsed
	if err := json.Unmarshal([]byte(nodesJSON), &nodes); err != nil {
		return nil, nil, fmt.Errorf("invalid nodes JSON: %w", err)
	}
	var edges []WorkflowEdgeParsed
	if err := json.Unmarshal([]byte(edgesJSON), &edges); err != nil {
		return nil, nil, fmt.Errorf("invalid edges JSON: %w", err)
	}
	return nodes, edges, nil
}

// validateWorkflowStructure ensures the workflow DAG is well-formed.
func validateWorkflowStructure(nodes []WorkflowNodeParsed, edges []WorkflowEdgeParsed) error {
	if len(nodes) > 20 {
		return fmt.Errorf("too many nodes: %d (max 20)", len(nodes))
	}
	if len(edges) > 30 {
		return fmt.Errorf("too many edges: %d (max 30)", len(edges))
	}

	nodeMap := make(map[string]*WorkflowNodeParsed, len(nodes))
	startCount := 0
	endCount := 0
	for i := range nodes {
		n := &nodes[i]
		nodeMap[n.ID] = n
		switch n.Type {
		case "start":
			startCount++
		case "end":
			endCount++
		case "agent":
			if _, err := strconv.ParseUint(n.RefID, 10, 64); err != nil {
				return fmt.Errorf("agent node %q has invalid ref_id %q: must be a valid uint", n.ID, n.RefID)
			}
		case "mission":
			if strings.TrimSpace(n.RefID) == "" {
				return fmt.Errorf("mission node %q has empty ref_id", n.ID)
			}
		}
	}
	if startCount != 1 {
		return fmt.Errorf("workflow must have exactly 1 start node, found %d", startCount)
	}
	if endCount < 1 {
		return fmt.Errorf("workflow must have at least 1 end node")
	}

	// Validate all edges reference valid node IDs.
	for _, e := range edges {
		if _, ok := nodeMap[e.From]; !ok {
			return fmt.Errorf("edge %q references unknown from-node %q", e.ID, e.From)
		}
		if _, ok := nodeMap[e.To]; !ok {
			return fmt.Errorf("edge %q references unknown to-node %q", e.ID, e.To)
		}
	}

	// Build DAG and check for cycles via topological sort.
	adj, inDegree, err := buildDAG(nodes, edges)
	if err != nil {
		return err
	}
	if _, err := topologicalSort(nodes, adj, inDegree); err != nil {
		return err
	}
	return nil
}

// buildDAG constructs an adjacency list and in-degree map from nodes and edges.
func buildDAG(nodes []WorkflowNodeParsed, edges []WorkflowEdgeParsed) (map[string][]string, map[string]int, error) {
	adj := make(map[string][]string, len(nodes))
	inDegree := make(map[string]int, len(nodes))
	for _, n := range nodes {
		adj[n.ID] = nil
		inDegree[n.ID] = 0
	}
	for _, e := range edges {
		adj[e.From] = append(adj[e.From], e.To)
		inDegree[e.To]++
	}
	return adj, inDegree, nil
}

// topologicalSort performs Kahn's algorithm. Returns an ordered list of node IDs
// or an error if a cycle is detected.
func topologicalSort(nodes []WorkflowNodeParsed, adj map[string][]string, inDegree map[string]int) ([]string, error) {
	queue := make([]string, 0)
	for _, n := range nodes {
		if inDegree[n.ID] == 0 {
			queue = append(queue, n.ID)
		}
	}

	var order []string
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		order = append(order, current)
		for _, neighbor := range adj[current] {
			inDegree[neighbor]--
			if inDegree[neighbor] == 0 {
				queue = append(queue, neighbor)
			}
		}
	}

	if len(order) != len(nodes) {
		return nil, fmt.Errorf("workflow contains a cycle")
	}
	return order, nil
}

// deductCredits atomically deducts credits and records a CreditTransaction.
// Uses row-level locking (SELECT ... FOR UPDATE) to prevent TOCTOU race conditions.
func (s *LegendService) deductCredits(wallet string, amount int64, executionID uint) error {
	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var user models.User
		// Lock the row for update to prevent concurrent balance races
		if err := dbTx.Set("gorm:query_option", "FOR UPDATE").
			Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
			return fmt.Errorf("user not found: %w", err)
		}
		if user.Credits < amount {
			return fmt.Errorf("insufficient credits: have %d, need %d", user.Credits, amount)
		}
		if err := dbTx.Model(&models.User{}).Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits - ?", amount)).Error; err != nil {
			return fmt.Errorf("failed to deduct credits: %w", err)
		}
		// Record transaction
		creditTx := models.CreditTransaction{
			Wallet: wallet,
			Type:   "workflow_execute",
			Amount: -amount,
		}
		return dbTx.Create(&creditTx).Error
	})
}

// executeNode runs a single workflow node and returns its output.
func (s *LegendService) executeNode(node WorkflowNodeParsed, contextInput, wallet string) (string, error) {
	switch node.Type {
	case "start":
		return contextInput, nil

	case "end":
		return contextInput, nil

	case "mission":
		mission, err := s.missionSvc.GetMissionBySlug(wallet, node.RefID)
		if err != nil {
			return "", fmt.Errorf("mission %q not found: %w", node.RefID, err)
		}
		// Increment use_count.
		database.DB.Model(&models.UserMission{}).
			Where("id = ?", mission.ID).
			UpdateColumn("use_count", gorm.Expr("use_count + 1"))
		return mission.Prompt, nil

	case "agent":
		agentID, err := strconv.ParseUint(node.RefID, 10, 64)
		if err != nil {
			return "", fmt.Errorf("invalid agent ref_id %q: %w", node.RefID, err)
		}
		var agent models.Agent
		if err := database.DB.First(&agent, uint(agentID)).Error; err != nil {
			return "", fmt.Errorf("agent %d not found: %w", agentID, err)
		}
		// Call Gemini chat with the agent's prompt as system instruction.
		output, err := s.geminiSvc.Chat(agent.Prompt, contextInput)
		if err != nil {
			return "", fmt.Errorf("gemini chat failed for agent %d: %w", agentID, err)
		}
		// Increment agent use_count.
		database.DB.Model(&models.Agent{}).
			Where("id = ?", agentID).
			UpdateColumn("use_count", gorm.Expr("use_count + 1"))
		return output, nil

	default:
		return "", fmt.Errorf("unknown node type %q", node.Type)
	}
}

// ExecuteWorkflow runs a workflow DAG end-to-end.
func (s *LegendService) ExecuteWorkflow(wallet string, input ExecuteWorkflowInput, workflowID string) (*ExecutionStatusDTO, error) {
	wallet = strings.ToLower(wallet)

	// 1. Load workflow from DB.
	var workflow models.UserLegendWorkflow
	if err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, workflowID).First(&workflow).Error; err != nil {
		return nil, fmt.Errorf("workflow not found: %w", err)
	}

	// 2. Parse workflow.
	nodes, edges, err := parseWorkflow(workflow.NodesJSON, workflow.EdgesJSON)
	if err != nil {
		return nil, fmt.Errorf("failed to parse workflow: %w", err)
	}

	// 3. Validate structure.
	if err := validateWorkflowStructure(nodes, edges); err != nil {
		return nil, fmt.Errorf("invalid workflow structure: %w", err)
	}

	// 4. Count agent nodes to determine credit cost.
	var requiredCredits int64
	for _, n := range nodes {
		if n.Type == "agent" {
			requiredCredits++
		}
	}

	// 5. Check user credits.
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if user.Credits < requiredCredits {
		return nil, fmt.Errorf("insufficient credits: have %d, need %d", user.Credits, requiredCredits)
	}

	// 6. Create execution record.
	execution := &models.WorkflowExecution{
		UserWallet:   wallet,
		WorkflowID:   workflowID,
		WorkflowName: workflow.Name,
		Status:       "running",
		InputMessage: input.InputMessage,
		TotalNodes:   len(nodes),
	}
	if err := database.DB.Create(execution).Error; err != nil {
		return nil, fmt.Errorf("failed to create execution record: %w", err)
	}

	// 7. Topological sort.
	adj, inDegree, _ := buildDAG(nodes, edges)
	order, _ := topologicalSort(nodes, adj, inDegree)

	// Build reverse adjacency (predecessors) for input gathering.
	predecessors := make(map[string][]string, len(nodes))
	for _, e := range edges {
		predecessors[e.To] = append(predecessors[e.To], e.From)
	}

	// Build node lookup map.
	nodeMap := make(map[string]*WorkflowNodeParsed, len(nodes))
	for i := range nodes {
		nodeMap[nodes[i].ID] = &nodes[i]
	}

	// 8. Execute nodes in topological order.
	nodeOutputs := make(map[string]string, len(nodes))
	var nodeResults []NodeExecutionResult

	for _, nodeID := range order {
		node := nodeMap[nodeID]

		// Gather input from predecessors.
		var contextInput string
		preds := predecessors[nodeID]
		if len(preds) == 0 {
			// Start node or orphan: use original input message.
			contextInput = input.InputMessage
		} else {
			parts := make([]string, 0, len(preds))
			for _, predID := range preds {
				if out, ok := nodeOutputs[predID]; ok && out != "" {
					parts = append(parts, out)
				}
			}
			contextInput = strings.Join(parts, "\n\n---\n\n")
		}

		startTime := time.Now()
		output, execErr := s.executeNode(*node, contextInput, wallet)
		durationMs := time.Since(startTime).Milliseconds()

		// Truncate output to 10000 chars max.
		if len(output) > 10000 {
			output = output[:10000]
		}

		result := NodeExecutionResult{
			NodeID:     node.ID,
			NodeType:   node.Type,
			NodeLabel:  node.Label,
			Input:      contextInput,
			Output:     output,
			DurationMs: durationMs,
		}
		if node.Type == "agent" {
			if agentID, err := strconv.ParseUint(node.RefID, 10, 64); err == nil {
				aid := uint(agentID)
				result.AgentID = &aid
			}
		}

		if execErr != nil {
			result.Error = execErr.Error()
			nodeResults = append(nodeResults, result)

			// On failure: set status "failed", save error, NO credit deduction.
			resultsJSON, _ := json.Marshal(nodeResults)
			now := time.Now()
			database.DB.Model(execution).Updates(map[string]interface{}{
				"status":          "failed",
				"error_message":   execErr.Error(),
				"node_results":    string(resultsJSON),
				"completed_nodes": len(nodeResults),
				"finished_at":     &now,
			})

			return s.executionToDTO(execution.ID)
		}

		nodeOutputs[nodeID] = output
		nodeResults = append(nodeResults, result)

		// Update completed count in DB.
		database.DB.Model(execution).UpdateColumn("completed_nodes", len(nodeResults))
	}

	// 9. Success: deduct credits, set completed, save final output.
	// Final output is the output of the last end node in topological order.
	var finalOutput string
	for i := len(order) - 1; i >= 0; i-- {
		n := nodeMap[order[i]]
		if n.Type == "end" {
			finalOutput = nodeOutputs[n.ID]
			break
		}
	}

	if requiredCredits > 0 {
		if err := s.deductCredits(wallet, requiredCredits, execution.ID); err != nil {
			// Credit deduction failed — still mark completed but log the error.
			resultsJSON, _ := json.Marshal(nodeResults)
			now := time.Now()
			database.DB.Model(execution).Updates(map[string]interface{}{
				"status":          "completed",
				"final_output":    finalOutput,
				"node_results":    string(resultsJSON),
				"completed_nodes": len(nodeResults),
				"credits_used":    requiredCredits,
				"error_message":   fmt.Sprintf("credit deduction failed: %v", err),
				"finished_at":     &now,
			})
			return s.executionToDTO(execution.ID)
		}
	}

	resultsJSON, _ := json.Marshal(nodeResults)
	now := time.Now()
	database.DB.Model(execution).Updates(map[string]interface{}{
		"status":          "completed",
		"final_output":    finalOutput,
		"node_results":    string(resultsJSON),
		"completed_nodes": len(nodeResults),
		"credits_used":    requiredCredits,
		"finished_at":     &now,
	})

	return s.executionToDTO(execution.ID)
}

// GetExecution returns a single execution by ID, scoped to the given wallet.
func (s *LegendService) GetExecution(wallet string, execID uint) (*ExecutionStatusDTO, error) {
	wallet = strings.ToLower(wallet)
	var exec models.WorkflowExecution
	if err := database.DB.Where("user_wallet = ? AND id = ?", wallet, execID).First(&exec).Error; err != nil {
		return nil, fmt.Errorf("execution not found: %w", err)
	}
	return buildExecutionDTO(&exec)
}

// ListExecutions returns paginated executions, optionally filtered by workflow ID.
func (s *LegendService) ListExecutions(wallet, workflowID string, page, limit int) ([]ExecutionStatusDTO, int64, error) {
	wallet = strings.ToLower(wallet)
	query := database.DB.Model(&models.WorkflowExecution{}).Where("user_wallet = ?", wallet)
	if workflowID != "" {
		query = query.Where("workflow_id = ?", workflowID)
	}

	var total int64
	query.Count(&total)

	var executions []models.WorkflowExecution
	offset := (page - 1) * limit
	if err := query.Order("started_at DESC").Offset(offset).Limit(limit).Find(&executions).Error; err != nil {
		return nil, 0, err
	}

	dtos := make([]ExecutionStatusDTO, 0, len(executions))
	for i := range executions {
		dto, err := buildExecutionDTO(&executions[i])
		if err != nil {
			continue
		}
		dtos = append(dtos, *dto)
	}
	return dtos, total, nil
}

// executionToDTO reloads the execution from DB and converts to DTO.
func (s *LegendService) executionToDTO(execID uint) (*ExecutionStatusDTO, error) {
	var exec models.WorkflowExecution
	if err := database.DB.First(&exec, execID).Error; err != nil {
		return nil, fmt.Errorf("execution not found: %w", err)
	}
	return buildExecutionDTO(&exec)
}

// buildExecutionDTO converts a WorkflowExecution model to an ExecutionStatusDTO.
func buildExecutionDTO(exec *models.WorkflowExecution) (*ExecutionStatusDTO, error) {
	var nodeResults []NodeExecutionResult
	if exec.NodeResults != "" && exec.NodeResults != "[]" {
		if err := json.Unmarshal([]byte(exec.NodeResults), &nodeResults); err != nil {
			nodeResults = []NodeExecutionResult{}
		}
	}
	if nodeResults == nil {
		nodeResults = []NodeExecutionResult{}
	}

	return &ExecutionStatusDTO{
		ID:             exec.ID,
		WorkflowID:     exec.WorkflowID,
		WorkflowName:   exec.WorkflowName,
		Status:         exec.Status,
		InputMessage:   exec.InputMessage,
		FinalOutput:    exec.FinalOutput,
		NodeResults:    nodeResults,
		TotalNodes:     exec.TotalNodes,
		CompletedNodes: exec.CompletedNodes,
		CreditsUsed:    exec.CreditsUsed,
		ErrorMessage:   exec.ErrorMessage,
		StartedAt:      exec.StartedAt,
		FinishedAt:     exec.FinishedAt,
	}, nil
}
