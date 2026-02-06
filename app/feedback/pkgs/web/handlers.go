package web

import (
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"strings"
)

var (
	templateNameFeedback = "feedback.html"
	templateNameThanks   = "thanks.html"
	templatePath         = "/app/templates/*.html"
	templates            *template.Template
)

// initTemplates loads HTML templates once during server initialization
func initTemplates() error {
	var err error

	templates, err = template.ParseGlob(templatePath)
	if err != nil {
		return fmt.Errorf("failed to parse templates from %s: %w", templatePath, err)
	}

	slog.Info("Templates loaded successfully", "path", templatePath)

	return nil
}

// handleFeedbackForm displays the feedback form
func (s *Server) handleFeedbackForm(w http.ResponseWriter, r *http.Request) {
	slog.Debug("Handling feedback form request", "method", r.Method, "url", r.URL)

	// Only handle exact "/" path, not favicon.ico or other requests
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		slog.Warn("Received request for unknown path", "path", r.URL.Path)

		return
	}

	data := map[string]interface{}{
		"MaxMessageLength": s.maxMessageLength,
	}

	if err := templates.ExecuteTemplate(w, templateNameFeedback, data); err != nil {
		slog.Error("Failed to render template", "template", templateNameFeedback, "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// handleFeedbackSubmit processes the feedback form submission
func (s *Server) handleFeedbackSubmit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)

		return
	}

	if err := r.ParseForm(); err != nil {
		slog.Error("Failed to parse form", "error", err)
		http.Error(w, "Bad request", http.StatusBadRequest)

		return
	}

	// Validate sentiment
	sentiment := strings.TrimSpace(r.FormValue("sentiment"))
	if sentiment != "positive" && sentiment != "negative" {
		s.renderFormWithError(w, "Please select a valid sentiment")

		return
	}

	// Get message (optional)
	message := strings.TrimSpace(r.FormValue("message"))
	if len(message) > s.maxMessageLength {
		s.renderFormWithError(w, fmt.Sprintf("Message is too long (max %d characters)", s.maxMessageLength))

		return
	}

	feedback, err := s.dbSaveFeedback(r.Context(), sentiment, message)
	if err != nil {
		slog.Error("Failed to save feedback", "error", err)
		s.renderFormWithError(w, "Failed to save feedback. Please try again. If the problem persists, "+
			"please report this error to the system administrator.")

		return
	}

	slog.Info("Feedback saved successfully",
		"id", feedback.ID,
		"sentiment", sentiment)

	// Redirect to thank you page
	http.Redirect(w, r, "/thanks", http.StatusSeeOther)
}

// renderFormWithError renders the form with an error message
func (s *Server) renderFormWithError(w http.ResponseWriter, errorMsg string) {
	data := map[string]interface{}{
		"Error":            errorMsg,
		"MaxMessageLength": s.maxMessageLength,
	}

	w.WriteHeader(http.StatusBadRequest)
	if err := templates.ExecuteTemplate(w, templateNameFeedback, data); err != nil {
		slog.Error("Failed to render error template", "template", templateNameFeedback, "error", err)
	}
}

// handleThanks displays the thank you page
func (s *Server) handleThanks(w http.ResponseWriter, r *http.Request) {
	if err := templates.ExecuteTemplate(w, templateNameThanks, nil); err != nil {
		slog.Error("Failed to render thank you template", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}
