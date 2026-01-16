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
	baseURL  string
}

func NewAIService(chatRepo *repository.ChatRepository, taskRepo *repository.TaskRepository, userRepo *repository.UserRepository, apiKey string) *AIService {
	return &AIService{
		chatRepo: chatRepo,
		taskRepo: taskRepo,
		userRepo: userRepo,
		apiKey:   apiKey,
		model:    "llama-3.3-70b-versatile", // Groq's fastest model
		baseURL:  "https://api.groq.com/openai/v1",
	}
}

// OpenAI-compatible API structures (for Groq)
type ChatRequest struct {
	Model       string        `json:"model"`
	Messages    []ChatMessage `json:"messages"`
	Temperature float64       `json:"temperature"`
	MaxTokens   int           `json:"max_tokens,omitempty"`
}

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
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

	// 3. Build messages array (OpenAI format)
	var messages []ChatMessage

	// Add system message
	messages = append(messages, ChatMessage{
		Role:    "system",
		Content: systemPrompt,
	})

	// Add chat history
	for _, msg := range history {
		role := string(msg.Role)
		if role == "assistant" || role == "model" {
			role = "assistant"
		} else {
			role = "user"
		}
		messages = append(messages, ChatMessage{
			Role:    role,
			Content: msg.Content,
		})
	}

	// Add current user message
	messages = append(messages, ChatMessage{
		Role:    "user",
		Content: userMessage,
	})

	// 4. Create request
	reqBody := ChatRequest{
		Model:       s.model,
		Messages:    messages,
		Temperature: 0.7,
		MaxTokens:   1024,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		log.Printf("❌ AI Chat: Failed to marshal request: %v", err)
		return "", fmt.Errorf("gagal memproses request: %v", err)
	}

	// 5. Call Groq API
	url := fmt.Sprintf("%s/chat/completions", s.baseURL)
	log.Printf("🤖 AI Chat: Calling Groq API with model %s", s.model)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("❌ AI Chat: Failed to create request: %v", err)
		return "", fmt.Errorf("gagal membuat request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.apiKey))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
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

	var chatResp ChatResponse
	if err := json.Unmarshal(body, &chatResp); err != nil {
		log.Printf("❌ AI Chat: Failed to parse response: %v", err)
		return "", fmt.Errorf("gagal memproses respons AI: %v", err)
	}

	// Check for API error
	if chatResp.Error != nil {
		log.Printf("❌ AI Chat: Groq API error: %s (type: %s)", chatResp.Error.Message, chatResp.Error.Type)
		
		// Handle rate limit error with friendly message
		if strings.Contains(strings.ToLower(chatResp.Error.Type), "rate_limit") || strings.Contains(strings.ToLower(chatResp.Error.Message), "rate limit") {
			log.Println("⚠️ AI Chat: Rate limit exceeded, returning fallback response")
			return s.getFallbackResponse(userMessage), nil
		}
		
		return "", fmt.Errorf("AI error: %s", chatResp.Error.Message)
	}

	// Extract response text
	if len(chatResp.Choices) == 0 {
		log.Println("⚠️ AI Chat: Empty response from Groq")
		return "Maaf, saya tidak bisa memberikan jawaban saat ini.", nil
	}

	aiResponse := chatResp.Choices[0].Message.Content
	log.Printf("✅ AI Chat: Got response from Groq (%d chars)", len(aiResponse))

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

// getFallbackResponse returns a helpful response when API quota is exceeded
func (s *AIService) getFallbackResponse(userMessage string) string {
	msg := strings.ToLower(userMessage)
	
	// Schedule & Time Management
	if strings.Contains(msg, "jadwal") || strings.Contains(msg, "waktu") || 
	   strings.Contains(msg, "mengatur") && strings.Contains(msg, "kerja") {
		return "📅 Tips Mengatur Jadwal Kerja yang Baik:\n\n" +
			"1. **Tentukan jam kerja tetap** - Misalnya 09:00-17:00, dan patuhi konsisten\n" +
			"2. **Gunakan time blocking** - Alokasikan blok waktu spesifik untuk setiap jenis tugas\n" +
			"3. **Prioritaskan tugas penting di pagi hari** - Saat energi dan fokus masih tinggi\n" +
			"4. **Jadwalkan istirahat rutin** - 5-10 menit setiap 1-2 jam kerja\n" +
			"5. **Review jadwal di akhir hari** - Evaluasi apa yang berhasil dan perlu disesuaikan\n\n" +
			"💡 Gunakan fitur 'Jadwal Kerja' di profil Workradar untuk set jam kerja kamu!\n\n" +
			"💬 *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk saran yang lebih personal.*"
	}
	
	// Productivity & Focus tips
	if strings.Contains(msg, "produktif") || strings.Contains(msg, "fokus") || 
	   strings.Contains(msg, "efektif") || strings.Contains(msg, "efisien") {
		return "💡 Tips Produktivitas & Fokus Kerja:\n\n" +
			"1. **Teknik Pomodoro** - 25 menit fokus, 5 menit istirahat\n" +
			"2. **Eisenhower Matrix** - Prioritaskan: Urgent & Important > Important > Urgent > Neither\n" +
			"3. **Hindari multitasking** - Fokus satu tugas sampai selesai\n" +
			"4. **Matikan notifikasi** - Saat deep work, silent mode!\n" +
			"5. **Morning routine** - Mulai hari dengan ritual yang sama\n\n" +
			"🎯 Coba gunakan timer di Workradar untuk track waktu kerja kamu!\n\n" +
			"💬 *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk respons yang lebih personal.*"
	}
	
	// Motivation & Encouragement
	if strings.Contains(msg, "motivasi") || strings.Contains(msg, "semangat") || 
	   strings.Contains(msg, "malas") || strings.Contains(msg, "jenuh") {
		return "🌟 Motivasi & Semangat Kerja:\n\n" +
			"\"Kesuksesan adalah hasil dari persiapan, kerja keras, dan belajar dari kegagalan.\" - Colin Powell\n\n" +
			"💪 **Tips bangkit semangat:**\n" +
			"• Ingat tujuan besar kamu - WHY you started?\n" +
			"• Rayakan small wins - Setiap progress itu penting!\n" +
			"• Istirahat sejenak - Recharge is not wasting time\n" +
			"• Connect dengan teman - Share your struggles\n\n" +
			"Setiap langkah kecil hari ini membawa kamu lebih dekat ke goal! 🎯\n\n" +
			"💬 *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk motivasi yang lebih personal.*"
	}
	
	// Task Management
	if strings.Contains(msg, "tugas") || strings.Contains(msg, "task") || 
	   strings.Contains(msg, "deadline") || strings.Contains(msg, "pekerjaan") {
		return "📋 Tips Manajemen Tugas yang Efektif:\n\n" +
			"1. **Brain dump** - Tulis semua tugas di kepala ke list\n" +
			"2. **Break down** - Pecah tugas besar jadi subtask kecil\n" +
			"3. **Set realistic deadline** - Jangan terlalu ambitious\n" +
			"4. **Daily top 3** - Pilih 3 tugas prioritas hari ini\n" +
			"5. **Evening review** - Check apa yang done & plan besok\n\n" +
			"📊 Cek dashboard Workradar untuk statistik tugas kamu!\n\n" +
			"💬 *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk analisis tugas yang lebih detail.*"
	}
	
	// Stress & Mental Health
	if strings.Contains(msg, "stres") || strings.Contains(msg, "lelah") || 
	   strings.Contains(msg, "burnout") || strings.Contains(msg, "cape") || strings.Contains(msg, "capek") {
		return "🧘 Tips Mengatasi Stres & Burnout:\n\n" +
			"1. **Teknik pernapasan 4-7-8** - Tarik napas 4 detik, tahan 7 detik, hembuskan 8 detik\n" +
			"2. **Physical movement** - Stretching, jalan kaki, atau olahraga ringan\n" +
			"3. **Digital detox** - 15-30 menit break dari semua layar\n" +
			"4. **Talk to someone** - Sharing helps more than you think\n" +
			"5. **Sleep enough** - 7-8 jam, non-negotiable!\n\n" +
			"💚 Kesehatan mental sama pentingnya dengan produktivitas. Take care of yourself!\n\n" +
			"� *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk saran yang lebih personal.*"
	}
	
	// Work-life balance
	if strings.Contains(msg, "balance") || strings.Contains(msg, "keseimbangan") || 
	   (strings.Contains(msg, "kerja") && strings.Contains(msg, "hidup")) {
		return "⚖️ Tips Work-Life Balance:\n\n" +
			"1. **Set boundaries** - Jam kerja selesai = stop working\n" +
			"2. **Quality time** - Dedikasikan waktu penuh untuk keluarga/hobi\n" +
			"3. **Say no** - Tidak semua request harus diiyakan\n" +
			"4. **Weekly reflection** - Evaluate work-life balance tiap minggu\n" +
			"5. **Self-care ritual** - Minimal 30 menit untuk diri sendiri tiap hari\n\n" +
			"🌿 Remember: You are not your job. You are a human being with a life!\n\n" +
			"💬 *Note: AI sedang dalam mode hemat. Coba lagi dalam beberapa saat untuk saran yang lebih personal.*"
	}
	
	// Default fallback with more helpful guidance
	return "👋 Halo! Saya asisten produktivitas Workradar.\n\n" +
		"Maaf, saat ini saya sedang dalam mode hemat karena banyaknya permintaan. " +
		"Tapi saya tetap bisa bantu! 💪\n\n" +
		"🎯 **Coba tanya saya tentang:**\n" +
		"• \"bagaimana mengatur jadwal kerja?\"\n" +
		"• \"tips produktif dan fokus\"\n" +
		"• \"cara manajemen tugas yang baik\"\n" +
		"• \"motivasi untuk semangat kerja\"\n" +
		"• \"cara mengatasi stres\"\n\n" +
		"Atau tunggu 1-2 menit untuk mendapat respons AI yang lebih detail! 🤖\n\n" +
		"� *Sementara itu, cek dashboard Workradar untuk melihat statistik tugas kamu.*"
}
