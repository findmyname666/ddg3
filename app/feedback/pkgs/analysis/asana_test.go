package analysis

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
)

func TestCalculateFeedbackSummary(t *testing.T) {
	tests := []struct {
		name     string
		counts   *db.CountFeedbackBySentimentRow
		expected FeedbackSummary
	}{
		{
			name: "normal case with positive and negative",
			counts: &db.CountFeedbackBySentimentRow{
				PositiveCount: 75,
				NegativeCount: 25,
			},
			expected: FeedbackSummary{
				PositiveCount:   75,
				NegativeCount:   25,
				Total:           100,
				PositivePercent: 75.0,
				NegativePercent: 25.0,
			},
		},
		{
			name: "all positive feedback",
			counts: &db.CountFeedbackBySentimentRow{
				PositiveCount: 100,
				NegativeCount: 0,
			},
			expected: FeedbackSummary{
				PositiveCount:   100,
				NegativeCount:   0,
				Total:           100,
				PositivePercent: 100.0,
				NegativePercent: 0.0,
			},
		},
		{
			name: "all negative feedback",
			counts: &db.CountFeedbackBySentimentRow{
				PositiveCount: 0,
				NegativeCount: 50,
			},
			expected: FeedbackSummary{
				PositiveCount:   0,
				NegativeCount:   50,
				Total:           50,
				PositivePercent: 0.0,
				NegativePercent: 100.0,
			},
		},
		{
			name: "no feedback",
			counts: &db.CountFeedbackBySentimentRow{
				PositiveCount: 0,
				NegativeCount: 0,
			},
			expected: FeedbackSummary{
				PositiveCount:   0,
				NegativeCount:   0,
				Total:           0,
				PositivePercent: 0.0,
				NegativePercent: 0.0,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateFeedbackSummary(tt.counts)

			if result.PositiveCount != tt.expected.PositiveCount {
				t.Errorf("PositiveCount: expected %d, got %d", tt.expected.PositiveCount, result.PositiveCount)
			}

			if result.NegativeCount != tt.expected.NegativeCount {
				t.Errorf("NegativeCount: expected %d, got %d", tt.expected.NegativeCount, result.NegativeCount)
			}

			if result.Total != tt.expected.Total {
				t.Errorf("Total: expected %d, got %d", tt.expected.Total, result.Total)
			}

			if result.PositivePercent != tt.expected.PositivePercent {
				t.Errorf(
					"PositivePercent: expected %.1f, got %.1f",
					tt.expected.PositivePercent,
					result.PositivePercent,
				)
			}

			if result.NegativePercent != tt.expected.NegativePercent {
				t.Errorf(
					"NegativePercent: expected %.1f, got %.1f",
					tt.expected.NegativePercent,
					result.NegativePercent,
				)
			}
		})
	}
}

func TestFormatTaskName(t *testing.T) {
	windowEnd := time.Date(2024, time.June, 15, 0, 0, 0, 0, time.UTC)
	expected := "Daily Feedback Summary - 2024-06-15"

	result := formatTaskName(windowEnd)

	if result != expected {
		t.Errorf("Expected %q, got %q", expected, result)
	}
}

func TestFormatTaskNotes(t *testing.T) {
	summary := &FeedbackSummary{
		PositiveCount:   75,
		NegativeCount:   25,
		Total:           100,
		PositivePercent: 75.0,
		NegativePercent: 25.0,
	}
	windowStart := time.Date(2024, time.June, 14, 0, 0, 0, 0, time.UTC)
	windowEnd := time.Date(2024, time.June, 15, 0, 0, 0, 0, time.UTC)

	result := formatTaskNotes(summary, windowStart, windowEnd)

	// Check that the result contains expected content
	expectedSubstrings := []string{
		"Feedback Summary Report",
		"Window: 2024-06-14 00:00 to 2024-06-15 00:00 (UTC)",
		"Positive: 75 (75.0%)",
		"Negative: 25 (25.0%)",
		"Total: 100",
		"feedback analysis job",
	}

	for _, substr := range expectedSubstrings {
		if !strings.Contains(result, substr) {
			t.Errorf("Expected result to contain %q, but it didn't.\nGot: %s", substr, result)
		}
	}
}

func TestBuildTaskRequest(t *testing.T) {
	expectedAsanaWorkspace := "workspace-123"
	expectedAsanaProject := "project-456"

	client := newAsanaClient("test-token", expectedAsanaWorkspace, expectedAsanaProject)
	summary := &FeedbackSummary{
		PositiveCount:   80,
		NegativeCount:   20,
		Total:           100,
		PositivePercent: 80.0,
		NegativePercent: 20.0,
	}
	windowStart := time.Date(2024, time.June, 14, 0, 0, 0, 0, time.UTC)
	windowEnd := time.Date(2024, time.June, 15, 0, 0, 0, 0, time.UTC)

	request := client.buildTaskRequest(summary, windowStart, windowEnd)

	// Verify workspace is set
	if request.Data.Workspace != expectedAsanaWorkspace {
		t.Errorf(
			"Expected workspace %q, got %q",
			expectedAsanaWorkspace,
			request.Data.Workspace,
		)
	}

	// Verify request structure
	if request.Data.Name != "Daily Feedback Summary - 2024-06-15" {
		t.Errorf(
			"Expected task name 'Daily Feedback Summary - 2024-06-15', got %q",
			request.Data.Name,
		)
	}

	if !strings.Contains(request.Data.Notes, "Positive: 80 (80.0%)") {
		t.Errorf(
			"Expected notes to contain positive count, got %q",
			request.Data.Notes,
		)
	}

	if request.Data.Completed {
		t.Error("Expected task to not be completed")
	}

	// Verify project GID is included
	if len(request.Data.Projects) != 1 {
		t.Errorf("Expected 1 project, got %d", len(request.Data.Projects))
	}

	if request.Data.Projects[0] != expectedAsanaProject {
		t.Errorf("Expected project %q, got %q", expectedAsanaProject, request.Data.Projects[0])
	}
}

func TestAsanaClient_SendRequest_Success(t *testing.T) {
	expectedAsanaTaskGID := "1234567890"
	expectedAsanaWorkspace := "workspace-123"
	expectedAsanaProject := "project-456"

	// Create a mock HTTP server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request method
		if r.Method != http.MethodPost {
			t.Errorf("Expected POST request, got %s", r.Method)
		}

		// Verify URL path (test server doesn't have /api/1.0 prefix)
		if r.URL.Path != "/tasks" {
			t.Errorf("Expected path '/tasks', got %q", r.URL.Path)
		}

		// Verify headers
		if auth := r.Header.Get("Authorization"); auth != "Bearer test-token" {
			t.Errorf("Expected Authorization header 'Bearer test-token', got %q", auth)
		}
		if ct := r.Header.Get("Content-Type"); ct != "application/json" {
			t.Errorf("Expected Content-Type 'application/json', got %q", ct)
		}

		// Verify request body
		var requestBody AsanaTaskRequest
		if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
			t.Errorf("Failed to decode request body: %v", err)
		}
		if requestBody.Data.Name != "Test Task" {
			t.Errorf("Expected task name 'Test Task', got %q", requestBody.Data.Name)
		}
		// Verify workspace is present in request
		if requestBody.Data.Workspace != expectedAsanaWorkspace {
			t.Errorf(
				"Expected workspace %q, got %q",
				expectedAsanaWorkspace,
				requestBody.Data.Workspace,
			)
		}

		// Send success response
		w.WriteHeader(http.StatusCreated)
		response := AsanaTaskResponse{
			Data: AsanaTaskResponseData{
				GID: expectedAsanaTaskGID,
			},
		}
		if err := json.NewEncoder(w).Encode(response); err != nil {
			t.Errorf("Failed to encode response: %v", err)
		}
	}))
	defer server.Close()

	// Create client with custom HTTP client pointing to test server
	client := &AsanaClient{
		token:        "test-token",
		workspaceGID: expectedAsanaWorkspace,
		projectGID:   expectedAsanaProject,
		httpClient:   server.Client(),
		baseURL:      server.URL,
	}

	// Prepare request data
	requestData := AsanaTaskRequest{
		Data: AsanaTaskData{
			Workspace: expectedAsanaWorkspace,
			Name:      "Test Task",
			Notes:     "Test Notes",
			Completed: false,
			Projects:  []string{expectedAsanaProject},
		},
	}
	jsonData, err := json.Marshal(requestData)
	if err != nil {
		t.Fatalf("Failed to marshal request: %v", err)
	}

	// Actually send the request
	ctx := context.Background()
	response, err := client.sendRequest(ctx, jsonData)
	if err != nil {
		t.Fatalf("sendRequest failed: %v", err)
	}

	// Verify response
	if response.Data.GID != expectedAsanaTaskGID {
		t.Errorf("Expected GID %q, got %q", expectedAsanaTaskGID, response.Data.GID)
	}
}

func TestAsanaTaskRequest_JSONMarshaling(t *testing.T) {
	expectedAsanaWorkspace := "workspace-123"
	expectedAsanaProject := "project-456"

	request := AsanaTaskRequest{
		Data: AsanaTaskData{
			Workspace: expectedAsanaWorkspace,
			Name:      "Daily Feedback Summary - 2024-06-15",
			Notes:     "Test notes",
			Completed: false,
			Projects:  []string{expectedAsanaProject},
		},
	}

	// Marshal to JSON
	jsonData, err := json.Marshal(request)
	if err != nil {
		t.Fatalf("Failed to marshal request: %v", err)
	}

	// Unmarshal back
	var parsed AsanaTaskRequest
	if err := json.Unmarshal(jsonData, &parsed); err != nil {
		t.Fatalf("Failed to unmarshal request: %v", err)
	}

	// Verify fields
	if parsed.Data.Workspace != request.Data.Workspace {
		t.Errorf("Expected workspace %q, got %q", request.Data.Workspace, parsed.Data.Workspace)
	}

	if parsed.Data.Name != request.Data.Name {
		t.Errorf("Expected name %q, got %q", request.Data.Name, parsed.Data.Name)
	}

	if parsed.Data.Notes != request.Data.Notes {
		t.Errorf("Expected notes %q, got %q", request.Data.Notes, parsed.Data.Notes)
	}

	if parsed.Data.Completed {
		t.Error("Expected completed to be false")
	}

	// Verify project is included
	if len(parsed.Data.Projects) != 1 {
		t.Errorf("Expected 1 project, got %d", len(parsed.Data.Projects))
	}

	if parsed.Data.Projects[0] != expectedAsanaProject {
		t.Errorf("Expected project %q, got %q", expectedAsanaProject, parsed.Data.Projects[0])
	}
}

func TestAsanaTaskResponse_JSONUnmarshaling(t *testing.T) {
	expectedAsanaTaskGID := "1234567890"
	// Simulate Asana API response
	jsonResponse := `{
  		"data": {
    		"gid": "1234567890",
    		"resource_type": "task",
    		"name": "Bug Task",
    		"resource_subtype": "default_task",
    		"created_by": {
    			"gid": "1111",
    			"resource_type": "user"
    		}
		}
  	}`

	var response AsanaTaskResponse
	if err := json.Unmarshal([]byte(jsonResponse), &response); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if response.Data.GID != expectedAsanaTaskGID {
		t.Errorf("Expected GID '%s', got %q", expectedAsanaTaskGID, response.Data.GID)
	}
}
