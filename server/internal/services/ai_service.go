package services

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/generative-ai-go/genai"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"google.golang.org/api/option"
)

type AIService struct {
	chatRepo *repository.ChatRepository
	taskRepo *repository.TaskRepository
	userRepo *repository.UserRepository
	apiKey   string
	model    string
	ctx      context.Context
}

func NewAIService(chatRepo *repository.ChatRepository, taskRepo *repository.TaskRepository, userRepo *repository.UserRepository, apiKey string) *AIService {
	return &AIService{
		chatRepo: chatRepo,
		taskRepo: taskRepo,
		userRepo: userRepo,
		apiKey:   apiKey,
		model:    "gemini-1.5-flash", // Fixed: removed -latest suffix
		ctx:      context.Background(),
	}
}

func (s *AIService) GenerateResponse(userID, userMessage string) (string, error) {
	log.Printf("🤖 AI Chat: Starting response generation for user %s", userID)

	if s.apiKey == "" {
		log.Println("⚠️ AI Chat: API key is empty!")
		return "Maaf, AI assistant belum dikonfigurasi. Silakan hubungi admin.", nil
	}

	log.Printf("🤖 AI Chat: Creating Gemini client with model %s", s.model)
	client, err := genai.NewClient(s.ctx, option.WithAPIKey(s.apiKey))
	if err != nil {
		log.Printf("❌ AI Chat: Failed to create Gemini client: %v", err)
		return "", fmt.Errorf("gagal menghubungi AI: %v", err)
	}
	defer client.Close()

	model := client.GenerativeModel(s.model)
	model.SetTemperature(0.7)

	// 1. Build context from user's data
	log.Printf("🤖 AI Chat: Building system prompt for user %s", userID)
	systemPrompt, err := s.buildSystemPrompt(userID)
	if err != nil {
		log.Printf("⚠️ AI Chat: Error building system prompt: %v", err)
		systemPrompt = "Anda adalah asisten produktivitas Workradar."
	}

	// 2. Load recent chat history from DB
	log.Println("🤖 AI Chat: Loading chat history from DB")
	history, err := s.chatRepo.FindByUserID(userID, 10) // Last 10 messages
	if err != nil {
		log.Printf("⚠️ AI Chat: Error loading chat history: %v", err)
	}
	log.Printf("🤖 AI Chat: Loaded %d messages from history", len(history))

	// 3. Initialize chat session with history
	cs := model.StartChat()
	model.SystemInstruction = &genai.Content{
		Parts: []genai.Part{genai.Text(systemPrompt)},
	}

	var genaiHistory []*genai.Content
	for _, msg := range history {
		role := string(msg.Role)
		if role == "assistant" {
			role = "model"
		}
		genaiHistory = append(genaiHistory, &genai.Content{
			Role:  role,
			Parts: []genai.Part{genai.Text(msg.Content)},
		})
	}
	cs.History = genaiHistory

	// 4. Send message to AI
	log.Printf("🤖 AI Chat: Sending message to Gemini: %s", userMessage)
	resp, err := cs.SendMessage(s.ctx, genai.Text(userMessage))
	if err != nil {
		log.Printf("❌ AI Chat: Gemini API error: %v", err)
		return "", fmt.Errorf("AI sedang sibuk. Coba lagi nanti. (%v)", err)
	}

	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		log.Println("⚠️ AI Chat: Empty response from Gemini")
		return "Maaf, saya tidak bisa memberikan jawaban saat ini.", nil
	}

	aiResponse := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		if text, ok := part.(genai.Text); ok {
			aiResponse += string(text)
		}
	}
	log.Printf("✅ AI Chat: Got response from Gemini (%d chars)", len(aiResponse))

	// 5. Save conversation to history
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
