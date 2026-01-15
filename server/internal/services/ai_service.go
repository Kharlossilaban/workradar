package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

type AIService struct {
	chatRepo *repository.ChatRepository
	taskRepo *repository.TaskRepository
	userRepo *repository.UserRepository
	apiKey   string
	model    string
}

func NewAIService(chatRepo *repository.ChatRepository, taskRepo *repository.TaskRepository, userRepo *repository.UserRepository, apiKey string) *AIService {
	return &AIService{
		chatRepo: chatRepo,
		taskRepo: taskRepo,
		userRepo: userRepo,
		apiKey:   apiKey,
		model:    "gemini-1.5-flash-latest", // Use v1beta with separate quota pool
	}
}

// Gemini REST API request/response structures
type GeminiRequest struct {
	Contents          []GeminiContent  `json:"contents"`
	SystemInstruction *GeminiContent   `json:"systemInstruction,omitempty"`
	GenerationConfig  *GeminiGenConfig `json:"generationConfig,omitempty"`
}

type GeminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []GeminiPart `json:"parts"`
}

type GeminiPart struct {
	Text string `json:"text"`
}

type GeminiGenConfig struct {
	Temperature float64 `json:"temperature"`
}

type GeminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Message string `json:"message"`
		Code    int    `json:"code"`
	} `json:"error,omitempty"`
}

func (s *AIService) GenerateResponse(userID, userMessage string) (string, error) {
	log.Printf("🤖 AI Chat: Starting response generation for user %s", userID)

	if s.apiKey == "" {
		log.Println("⚠️ AI Chat: API key is empty!")
		return "Maaf, AI assistant belum dikonfigurasi. Silakan hubungi admin.", nil
	}

	// 1. Build system prompt
	log.Printf("🤖 AI Chat: Building system prompt for user %s", userID)
	systemPrompt, err := s.buildSystemPrompt(userID)
	if err != nil {
		log.Printf("⚠️ AI Chat: Error building system prompt: %v", err)
		systemPrompt = "Anda adalah asisten produktivitas Workradar."
	}

	// 2. Load chat history
	log.Println("🤖 AI Chat: Loading chat history from DB")
	history, err := s.chatRepo.FindByUserID(userID, 10)
	if err != nil {
		log.Printf("⚠️ AI Chat: Error loading chat history: %v", err)
	}
	log.Printf("🤖 AI Chat: Loaded %d messages from history", len(history))

	// 3. Build request contents
	var contents []GeminiContent

	// Add system context as first user-model exchange (only if no history)
	if len(history) == 0 {
		contents = append(contents, GeminiContent{
			Role:  "user",
			Parts: []GeminiPart{{Text: "Kamu adalah siapa? Apa yang bisa kamu bantu?"}},
		})
		contents = append(contents, GeminiContent{
			Role:  "model",
			Parts: []GeminiPart{{Text: systemPrompt}},
		})
	}

	// Add chat history
	for _, msg := range history {
		role := string(msg.Role)
		if role == "assistant" || role == "model" {
			role = "model"
		} else {
			role = "user"
		}
		contents = append(contents, GeminiContent{
			Role:  role,
			Parts: []GeminiPart{{Text: msg.Content}},
		})
	}

	// Add current user message
	contents = append(contents, GeminiContent{
		Role:  "user",
		Parts: []GeminiPart{{Text: userMessage}},
	})

	// 4. Create request (without systemInstruction)
	reqBody := GeminiRequest{
		Contents: contents,
		GenerationConfig: &GeminiGenConfig{
			Temperature: 0.7,
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		log.Printf("❌ AI Chat: Failed to marshal request: %v", err)
		return "", fmt.Errorf("gagal memproses request: %v", err)
	}

	// 5. Call Gemini REST API (v1beta endpoint with gemini-1.5-flash-latest)
	url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", s.model, s.apiKey)
	log.Printf("🤖 AI Chat: Calling Gemini API with model %s", s.model)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("❌ AI Chat: HTTP request failed: %v", err)
		return "", fmt.Errorf("gagal menghubungi AI: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("❌ AI Chat: Failed to read response: %v", err)
		return "", fmt.Errorf("gagal membaca respons AI: %v", err)
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(body, &geminiResp); err != nil {
		log.Printf("❌ AI Chat: Failed to parse response: %v", err)
		return "", fmt.Errorf("gagal memproses respons AI: %v", err)
	}

	// Check for API error
	if geminiResp.Error != nil {
		log.Printf("❌ AI Chat: Gemini API error: %s (code: %d)", geminiResp.Error.Message, geminiResp.Error.Code)
		return "", fmt.Errorf("AI error: %s", geminiResp.Error.Message)
	}

	// Extract response text
	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		log.Println("⚠️ AI Chat: Empty response from Gemini")
		return "Maaf, saya tidak bisa memberikan jawaban saat ini.", nil
	}

	aiResponse := geminiResp.Candidates[0].Content.Parts[0].Text
	log.Printf("✅ AI Chat: Got response from Gemini (%d chars)", len(aiResponse))

	// 6. Save conversation to DB
	log.Println("🤖 AI Chat: Saving conversation to DB")
	s.chatRepo.Create(&models.ChatMessage{
		UserID:  userID,
		Role:    models.ChatRoleUser,
		Content: userMessage,
	})

	s.chatRepo.Create(&models.ChatMessage{
		UserID:  userID,
		Role:    models.ChatRoleModel,
		Content: aiResponse,
	})

	log.Println("✅ AI Chat: Response generation completed successfully")
	return aiResponse, nil
}

func (s *AIService) buildSystemPrompt(userID string) (string, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return "", err
	}

	tasks, _ := s.taskRepo.FindByUserID(userID)

	pendingTasks := 0
	completedTasks := 0
	var upcomingDeadlines []string

	for _, t := range tasks {
		if t.IsCompleted {
			completedTasks++
		} else {
			pendingTasks++
			if t.Deadline != nil && t.Deadline.After(time.Now()) {
				deadlineStr := t.Deadline.Format("02 Jan 15:04")
				upcomingDeadlines = append(upcomingDeadlines, fmt.Sprintf("- %s (%s)", t.Title, deadlineStr))
			}
		}
	}

	var sb strings.Builder
	sb.WriteString("Anda adalah asisten produktivitas cerdas untuk aplikasi Workradar.\n")
	sb.WriteString(fmt.Sprintf("Nama User: %s\n", user.Username))
	sb.WriteString(fmt.Sprintf("Statistik Tugas:\n- Pending: %d\n- Selesai: %d\n", pendingTasks, completedTasks))

	if len(upcomingDeadlines) > 0 {
		sb.WriteString("Tugas Mendatang:\n")
		for _, d := range upcomingDeadlines {
			sb.WriteString(d + "\n")
		}
	}

	sb.WriteString("\nAturan:\n")
	sb.WriteString("1. Jawab dalam Bahasa Indonesia yang ramah dan profesional.\n")
	sb.WriteString("2. Usahakan jawaban singkat dan padat.\n")
	sb.WriteString("3. Fokus pada produktivitas dan psikologi kerja.\n")
	sb.WriteString("4. Jika user bertanya tentang tugas mereka, gunakan data statistik di atas.\n")

	return sb.String(), nil
}

func (s *AIService) GetChatHistory(userID string) ([]models.ChatMessage, error) {
	return s.chatRepo.FindByUserID(userID, 20)
}

func (s *AIService) ClearChatHistory(userID string) error {
	return s.chatRepo.DeleteByUserID(userID)
}
