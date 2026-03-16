package services

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
)

type SaveMissionInput struct {
	ID        string    `json:"id" binding:"required"`
	Title     string    `json:"title" binding:"required"`
	Slug      string    `json:"slug" binding:"required"`
	Prompt    string    `json:"prompt" binding:"required"`
	UseCount  int64     `json:"use_count"`
	CreatedAt time.Time `json:"created_at"`
}

type SaveLegendWorkflowInput struct {
	ID        string          `json:"id" binding:"required"`
	Name      string          `json:"name" binding:"required"`
	Nodes     json.RawMessage `json:"nodes" binding:"required"`
	Edges     json.RawMessage `json:"edges" binding:"required"`
	UpdatedAt time.Time       `json:"updated_at"`
}

type LegendWorkflowDTO struct {
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Nodes     json.RawMessage `json:"nodes"`
	Edges     json.RawMessage `json:"edges"`
	UpdatedAt time.Time       `json:"updated_at"`
}

func (s *AgentService) ListUserMissions(wallet string) ([]models.UserMission, error) {
	var missions []models.UserMission
	err := database.DB.
		Where("user_wallet = ?", strings.ToLower(wallet)).
		Order("use_count DESC, created_at DESC").
		Find(&missions).Error
	return missions, err
}

func (s *AgentService) SaveUserMission(wallet string, input SaveMissionInput) (*models.UserMission, error) {
	wallet = strings.ToLower(wallet)
	mission := &models.UserMission{}
	err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(mission).Error
	if err != nil {
		mission = &models.UserMission{
			UserWallet: wallet,
			ClientID:   input.ID,
			CreatedAt:  input.CreatedAt,
		}
	}
	if mission.CreatedAt.IsZero() {
		mission.CreatedAt = time.Now()
	}
	if !input.CreatedAt.IsZero() {
		mission.CreatedAt = input.CreatedAt
	}
	mission.Title = input.Title
	mission.Slug = input.Slug
	mission.Prompt = input.Prompt
	mission.UseCount = input.UseCount

	if err := database.DB.Save(mission).Error; err != nil {
		return nil, err
	}
	return mission, nil
}

func (s *AgentService) DeleteUserMission(wallet, clientID string) error {
	return database.DB.Where("user_wallet = ? AND client_id = ?", strings.ToLower(wallet), clientID).Delete(&models.UserMission{}).Error
}

func (s *AgentService) ListUserLegendWorkflows(wallet string) ([]LegendWorkflowDTO, error) {
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

func (s *AgentService) SaveUserLegendWorkflow(wallet string, input SaveLegendWorkflowInput) (*LegendWorkflowDTO, error) {
	if !json.Valid(input.Nodes) {
		return nil, fmt.Errorf("nodes must be valid JSON")
	}
	if !json.Valid(input.Edges) {
		return nil, fmt.Errorf("edges must be valid JSON")
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

func (s *AgentService) DeleteUserLegendWorkflow(wallet, clientID string) error {
	return database.DB.Where("user_wallet = ? AND client_id = ?", strings.ToLower(wallet), clientID).Delete(&models.UserLegendWorkflow{}).Error
}
