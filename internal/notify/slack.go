package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/raf181/Package-Updates-Noty/internal/config"
)

type Slack struct {
	webhook string
	client  *http.Client
}

type SlackMessage struct {
	Text   string        `json:"text,omitempty"`
	Blocks []interface{} `json:"blocks,omitempty"`
}

func NewSlack(cfg *config.Config) *Slack {
	return &Slack{
		webhook: cfg.SlackWebhook,
		client:  &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *Slack) Send(ctx context.Context, msg *SlackMessage) error {
	if s.webhook == "" {
		fmt.Println("[dry-run]", msg.Text)
		return nil
	}
	b, _ := json.Marshal(msg)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, s.webhook, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("slack webhook status %d", resp.StatusCode)
	}
	return nil
}

func SimpleText(text string) *SlackMessage { return &SlackMessage{Text: text} }
