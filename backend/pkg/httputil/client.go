package httputil

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ServiceClient provides HTTP communication between microservices.
type ServiceClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewServiceClient creates a new inter-service HTTP client.
func NewServiceClient(baseURL string) *ServiceClient {
	return &ServiceClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// NewServiceClientWithTimeout creates a client with a custom timeout.
func NewServiceClientWithTimeout(baseURL string, timeout time.Duration) *ServiceClient {
	return &ServiceClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

// Get performs an HTTP GET and decodes the JSON response into dest.
func (c *ServiceClient) Get(ctx context.Context, path string, dest interface{}) error {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+path, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	return c.doJSON(req, dest)
}

// GetWithWallet performs an HTTP GET with the X-Wallet-Address header.
func (c *ServiceClient) GetWithWallet(ctx context.Context, path, wallet string, dest interface{}) error {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+path, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("X-Wallet-Address", wallet)
	return c.doJSON(req, dest)
}

// Post performs an HTTP POST with a JSON body and decodes the response into dest.
func (c *ServiceClient) Post(ctx context.Context, path string, body interface{}, dest interface{}) error {
	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal body: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+path, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	return c.doJSON(req, dest)
}

// PostWithWallet performs an HTTP POST with the X-Wallet-Address header.
func (c *ServiceClient) PostWithWallet(ctx context.Context, path, wallet string, body interface{}, dest interface{}) error {
	data, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal body: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+path, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Wallet-Address", wallet)
	return c.doJSON(req, dest)
}

// PostRaw performs an HTTP POST and returns raw response bytes.
func (c *ServiceClient) PostRaw(ctx context.Context, path string, body interface{}) ([]byte, int, error) {
	data, err := json.Marshal(body)
	if err != nil {
		return nil, 0, fmt.Errorf("marshal body: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+path, bytes.NewReader(data))
	if err != nil {
		return nil, 0, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return b, resp.StatusCode, nil
}

func (c *ServiceClient) doJSON(req *http.Request, dest interface{}) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		return fmt.Errorf("service error %d: %s", resp.StatusCode, string(body))
	}

	if dest != nil && len(body) > 0 {
		if err := json.Unmarshal(body, dest); err != nil {
			return fmt.Errorf("decode response: %w", err)
		}
	}
	return nil
}
